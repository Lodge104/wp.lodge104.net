# EFS Access Point for Lambda
resource "aws_efs_access_point" "lambda" {
  file_system_id = var.efs_file_system_id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = var.efs_access_point_path
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "0755"
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-lambda-ap"
    Environment = var.environment
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.project_name}-${var.environment}-wp-deployer-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-wp-deployer-role"
    Environment = var.environment
  }
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.project_name}-${var.environment}-wp-deployer-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:ClientMount",
          "elasticfilesystem:ClientWrite",
          "elasticfilesystem:ClientRootAccess"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation",
          "ssm:ListCommandInvocations"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticbeanstalk:DescribeEnvironments",
          "elasticbeanstalk:DescribeEnvironmentResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# Lambda Function
resource "aws_lambda_function" "wordpress_deployer" {
  function_name = "${var.project_name}-${var.environment}-wp-deployer"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.10"
  timeout       = var.lambda_timeout
  memory_size   = 512

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  file_system_config {
    arn              = aws_efs_access_point.lambda.arn
    local_mount_path = "/mnt/efs"
  }

  environment {
    variables = {
      EFS_MOUNT_PATH      = "/mnt/efs"
      DB_HOST             = var.db_host
      DB_NAME             = var.db_name
      DB_USER             = var.db_username
      DB_PASSWORD         = var.db_password
      PRIMARY_DOMAIN      = var.primary_domain
      EB_ENVIRONMENT_NAME = var.eb_environment_name
      SITE_TITLE          = var.site_title
      ADMIN_USER          = var.admin_user
      ADMIN_EMAIL         = var.admin_email
    }
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-wp-deployer"
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy.lambda_policy,
    aws_efs_access_point.lambda
  ]
}

# Lambda source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"

  source {
    content  = local.lambda_code
    filename = "index.py"
  }
}

locals {
  lambda_code = <<-PYTHON
import os
import json
import urllib.request
import tarfile
import shutil
import secrets
import string
import time
import boto3

def get_eb_instance_ids(eb_environment_name):
    """Get instance IDs from Elastic Beanstalk environment."""
    eb_client = boto3.client('elasticbeanstalk')
    ec2_client = boto3.client('ec2')
    
    try:
        # Get environment resources
        response = eb_client.describe_environment_resources(
            EnvironmentName=eb_environment_name
        )
        
        instances = response.get('EnvironmentResources', {}).get('Instances', [])
        instance_ids = [i.get('Id') for i in instances if i.get('Id')]
        
        if not instance_ids:
            print(f"No instances found in environment {eb_environment_name}")
            return []
            
        # Verify instances are running and SSM managed
        ec2_response = ec2_client.describe_instances(InstanceIds=instance_ids)
        running_instances = []
        
        for reservation in ec2_response['Reservations']:
            for instance in reservation['Instances']:
                if instance['State']['Name'] == 'running':
                    running_instances.append(instance['InstanceId'])
        
        # Cross-check SSM managed instances in the account
        try:
          ssm_client = boto3.client('ssm')
          ssm_info = ssm_client.describe_instance_information()
          ssm_ids = {item['InstanceId'] for item in ssm_info.get('InstanceInformationList', [])}
          running_instances = [iid for iid in running_instances if iid in ssm_ids]
        except Exception as ssm_err:
          print(f"SSM check failed: {ssm_err}")

        return running_instances
        
    except Exception as e:
        print(f"Error getting EB instances: {str(e)}")
        return []

def run_ssm_command(instance_ids, commands, timeout=300):
    """Run SSM command on instances and wait for completion."""
    if not instance_ids:
        return {'success': False, 'error': 'No instances provided'}
    
    ssm_client = boto3.client('ssm')
    
    try:
        # Send command
        response = ssm_client.send_command(
            InstanceIds=instance_ids,
            DocumentName='AWS-RunShellScript',
            Parameters={'commands': commands},
            TimeoutSeconds=timeout
        )
        
        command_id = response['Command']['CommandId']
        print(f"SSM Command ID: {command_id}")
        
        # Wait for command to complete
        for _ in range(timeout // 5):
            time.sleep(5)
            
            # Check command status for each instance
            all_complete = True
            results = []
            
            for instance_id in instance_ids:
                try:
                    result = ssm_client.get_command_invocation(
                        CommandId=command_id,
                        InstanceId=instance_id
                    )
                    
                    status = result['Status']
                    if status in ['Pending', 'InProgress']:
                        all_complete = False
                    else:
                        results.append({
                            'instance_id': instance_id,
                            'status': status,
                            'output': result.get('StandardOutputContent', ''),
                            'error': result.get('StandardErrorContent', '')
                        })
                except ssm_client.exceptions.InvocationDoesNotExist:
                    all_complete = False
            
            if all_complete:
                return {'success': True, 'results': results}
        
        return {'success': False, 'error': 'Command timeout'}
        
    except Exception as e:
        return {'success': False, 'error': str(e)}

def install_wp_cli(instance_ids):
    """Install WP-CLI on instances."""
    commands = [
        'cd /tmp',
        'curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar',
        'chmod +x wp-cli.phar',
        'sudo mv wp-cli.phar /usr/local/bin/wp',
        'wp --info || echo "WP-CLI installation failed"'
    ]
    
    return run_ssm_command(instance_ids, commands)

def configure_wordpress(instance_ids, config):
    """Configure WordPress using WP-CLI."""
    db_host = config['db_host']
    db_name = config['db_name']
    db_user = config['db_user']
    db_password = config['db_password']
    site_url = config['site_url']
    site_title = config['site_title']
    admin_user = config['admin_user']
    admin_email = config['admin_email']
    wp_path = config['wp_path']
    
    # Generate random admin password with special characters for better security
    password_chars = string.ascii_letters + string.digits + '!@#$%^&*'
    admin_password = ''.join(secrets.choice(password_chars) for _ in range(20))
    
    commands = [
        f'cd {wp_path}',
        # Check if WordPress is already installed
        f'if sudo -u webapp wp core is-installed --path={wp_path} 2>/dev/null; then',
        f'  echo "WordPress already installed, updating configuration..."',
        f'  sudo -u webapp wp option update siteurl "{site_url}" --path={wp_path}',
        f'  sudo -u webapp wp option update home "{site_url}" --path={wp_path}',
        f'else',
        f'  echo "Installing WordPress..."',
        # Create wp-config.php if it does not exist
        f'  if [ ! -f {wp_path}/wp-config.php ]; then',
        f'    sudo -u webapp wp config create --dbname="{db_name}" --dbuser="{db_user}" --dbpass="{db_password}" --dbhost="{db_host}" --path={wp_path}',
        f'  fi',
        # Install WordPress
        f'  sudo -u webapp wp core install --url="{site_url}" --title="{site_title}" --admin_user="{admin_user}" --admin_password="{admin_password}" --admin_email="{admin_email}" --path={wp_path} --skip-email',
        f'  echo "WordPress installed. Admin credentials have been set."',
        f'fi',
        # Enable multisite if needed
        f'echo "WordPress configuration complete"'
    ]
    
    return run_ssm_command(instance_ids, commands, timeout=600)

def deploy_wordpress_files(efs_path, db_config):
    """Deploy WordPress files to EFS."""
    wordpress_dir = efs_path
    wp_config_path = os.path.join(wordpress_dir, 'wp-config.php')
    
    # Create directory if it doesn't exist
    os.makedirs(wordpress_dir, exist_ok=True)
    
    # Check if WordPress files exist
    if not os.path.exists(os.path.join(wordpress_dir, 'wp-includes')):
        # Download latest WordPress
        print("Downloading latest WordPress...")
        wp_url = "https://wordpress.org/latest.tar.gz"
        tmp_file = "/tmp/wordpress-latest.tar.gz"
        
        urllib.request.urlretrieve(wp_url, tmp_file)
        
        # Extract WordPress
        print("Extracting WordPress...")
        with tarfile.open(tmp_file, 'r:gz') as tar:
            tar.extractall('/tmp')
        
        # Copy files to EFS
        print("Copying WordPress files to EFS...")
        src_dir = '/tmp/wordpress'
        
        for item in os.listdir(src_dir):
            src_item = os.path.join(src_dir, item)
            dst_item = os.path.join(wordpress_dir, item)
            
            if os.path.isdir(src_item):
                if os.path.exists(dst_item):
                    shutil.copytree(src_item, dst_item, dirs_exist_ok=True)
                else:
                    shutil.copytree(src_item, dst_item)
            else:
                shutil.copy2(src_item, dst_item)
        
        # Set permissions
        print("Setting permissions...")
        for root, dirs, files in os.walk(wordpress_dir):
            for d in dirs:
                os.chmod(os.path.join(root, d), 0o755)
            for f in files:
                os.chmod(os.path.join(root, f), 0o644)
        
        # Cleanup
        os.remove(tmp_file)
        shutil.rmtree('/tmp/wordpress', ignore_errors=True)
        
        return True
    
    return False

def handler(event, context):
    """
    Lambda function to deploy and configure WordPress.
    
    Actions:
    - deploy: Deploy WordPress files to EFS
    - configure: Install WP-CLI and configure WordPress via SSM
    - full: Do both deploy and configure
    """
    efs_path = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
    db_host = os.environ.get('DB_HOST', '')
    db_name = os.environ.get('DB_NAME', 'wordpress')
    db_user = os.environ.get('DB_USER', 'admin')
    db_password = os.environ.get('DB_PASSWORD', '')
    primary_domain = os.environ.get('PRIMARY_DOMAIN', 'localhost')
    eb_environment_name = os.environ.get('EB_ENVIRONMENT_NAME', '')
    site_title = os.environ.get('SITE_TITLE', 'WordPress Site')
    admin_user = os.environ.get('ADMIN_USER', 'admin')
    admin_email = os.environ.get('ADMIN_EMAIL', 'admin@example.com')
    
    action = event.get('action', 'full')
    force_reinstall = event.get('force_reinstall', False)
    
    results = {
        'action': action,
        'deploy': None,
        'configure': None
    }
    
    try:
        # Deploy WordPress files
        if action in ['deploy', 'full']:
            print("Deploying WordPress files to EFS...")
            
            wp_exists = os.path.exists(os.path.join(efs_path, 'wp-includes'))
            
            if not wp_exists or force_reinstall:
                deployed = deploy_wordpress_files(efs_path, {
                    'db_host': db_host,
                    'db_name': db_name,
                    'db_user': db_user,
                    'db_password': db_password
                })
                results['deploy'] = {
                    'status': 'success',
                    'message': 'WordPress files deployed' if deployed else 'WordPress files already exist'
                }
            else:
                results['deploy'] = {
                    'status': 'skipped',
                    'message': 'WordPress files already exist'
                }
        
        # Configure WordPress via SSM
        if action in ['configure', 'full']:
            print("Configuring WordPress via SSM...")
            
            if not eb_environment_name:
                results['configure'] = {
                    'status': 'error',
                    'message': 'EB_ENVIRONMENT_NAME not set'
                }
            else:
                # Get instance IDs
                instance_ids = get_eb_instance_ids(eb_environment_name)
                
                if not instance_ids:
                    results['configure'] = {
                        'status': 'error',
                        'message': 'No running instances found in EB environment'
                    }
                else:
                    print(f"Found instances: {instance_ids}")
                    
                    # Install WP-CLI
                    print("Installing WP-CLI...")
                    wp_cli_result = install_wp_cli(instance_ids)
                    
                    if not wp_cli_result['success']:
                        results['configure'] = {
                            'status': 'error',
                            'message': f"WP-CLI installation failed: {wp_cli_result.get('error', 'Unknown error')}"
                        }
                    else:
                        # Configure WordPress
                        print("Configuring WordPress...")
                        site_url = f"https://{primary_domain}" if primary_domain else "http://localhost"
                        
                        config_result = configure_wordpress(instance_ids, {
                            'db_host': db_host,
                            'db_name': db_name,
                            'db_user': db_user,
                            'db_password': db_password,
                            'site_url': site_url,
                            'site_title': site_title,
                            'admin_user': admin_user,
                            'admin_email': admin_email,
                            'wp_path': '/var/www/html/wordpress'
                        })
                        
                        if config_result['success']:
                            results['configure'] = {
                                'status': 'success',
                                'message': 'WordPress configured successfully',
                                'details': config_result['results']
                            }
                        else:
                            results['configure'] = {
                                'status': 'error',
                                'message': f"WordPress configuration failed: {config_result.get('error', 'Unknown error')}"
                            }
        
        return {
            'statusCode': 200,
            'body': json.dumps(results)
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error: {str(e)}',
                'action': 'failed'
            })
        }
PYTHON
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.wordpress_deployer.function_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-wp-deployer-logs"
    Environment = var.environment
  }
}
