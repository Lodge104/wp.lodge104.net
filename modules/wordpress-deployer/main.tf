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
          "ec2:DeleteNetworkInterface"
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
  timeout       = 300
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
      EFS_MOUNT_PATH = "/mnt/efs"
      DB_HOST        = var.db_host
      DB_NAME        = var.db_name
      DB_USER        = var.db_username
      DB_PASSWORD    = var.db_password
      PRIMARY_DOMAIN = var.primary_domain
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

def handler(event, context):
    """
    Lambda function to deploy the latest WordPress to EFS.
    """
    efs_path = os.environ.get('EFS_MOUNT_PATH', '/mnt/efs')
    db_host = os.environ.get('DB_HOST', '')
    db_name = os.environ.get('DB_NAME', 'wordpress')
    db_user = os.environ.get('DB_USER', 'admin')
    db_password = os.environ.get('DB_PASSWORD', '')
    primary_domain = os.environ.get('PRIMARY_DOMAIN', 'localhost')
    
    wordpress_dir = efs_path
    wp_config_path = os.path.join(wordpress_dir, 'wp-config.php')
    
    try:
        # Check if WordPress is already installed
        force_reinstall = event.get('force_reinstall', False)
        
        if os.path.exists(wp_config_path) and not force_reinstall:
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'WordPress is already installed',
                    'path': wordpress_dir,
                    'action': 'skipped'
                })
            }
        
        # Create directory if it doesn't exist
        os.makedirs(wordpress_dir, exist_ok=True)
        
        # Download latest WordPress
        print("Downloading latest WordPress...")
        wp_url = "https://wordpress.org/latest.tar.gz"
        tmp_file = "/tmp/wordpress-latest.tar.gz"
        
        urllib.request.urlretrieve(wp_url, tmp_file)
        
        # Extract WordPress
        print("Extracting WordPress...")
        with tarfile.open(tmp_file, 'r:gz') as tar:
            tar.extractall('/tmp')
        
        # Copy files to EFS (merge if exists)
        print("Copying WordPress files to EFS...")
        src_dir = '/tmp/wordpress'
        
        for item in os.listdir(src_dir):
            src_item = os.path.join(src_dir, item)
            dst_item = os.path.join(wordpress_dir, item)
            
            if os.path.isdir(src_item):
                if os.path.exists(dst_item):
                    # Merge directories
                    for sub_item in os.listdir(src_item):
                        src_sub = os.path.join(src_item, sub_item)
                        dst_sub = os.path.join(dst_item, sub_item)
                        if os.path.isdir(src_sub):
                            shutil.copytree(src_sub, dst_sub, dirs_exist_ok=True)
                        else:
                            shutil.copy2(src_sub, dst_sub)
                else:
                    shutil.copytree(src_item, dst_item)
            else:
                shutil.copy2(src_item, dst_item)
        
        # Create wp-config.php
        print("Creating wp-config.php...")
        wp_config_sample = os.path.join(wordpress_dir, 'wp-config-sample.php')
        
        if os.path.exists(wp_config_sample):
            with open(wp_config_sample, 'r') as f:
                config_content = f.read()
            
            # Generate security keys/salts
            def generate_salt(length=64):
                chars = string.ascii_letters + string.digits + '!@#$%^&*()-_=+[]{}|;:,.<>?'
                return ''.join(secrets.choice(chars) for _ in range(length))
            
            # Replace database settings
            config_content = config_content.replace("'database_name_here'", f"'{db_name}'")
            config_content = config_content.replace("'username_here'", f"'{db_user}'")
            config_content = config_content.replace("'password_here'", f"'{db_password}'")
            config_content = config_content.replace("'localhost'", f"'{db_host}'")
            
            # Replace security keys
            keys = ['AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY', 
                    'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT']
            
            for key in keys:
                old_line = f"define( '{key}',         'put your unique phrase here' );"
                new_line = f"define( '{key}',         '{generate_salt()}' );"
                config_content = config_content.replace(old_line, new_line)
            
            # Add additional WordPress configurations before "That's all" comment
            additional_config = f'''
/* Custom WordPress Configuration */
define('FS_METHOD', 'direct');
define('WP_DEBUG', false);

/* WordPress Multi-site Configuration */
define('WP_ALLOW_MULTISITE', true);
define('MULTISITE', true);
define('SUBDOMAIN_INSTALL', true);
define('DOMAIN_CURRENT_SITE', '{primary_domain}');
define('PATH_CURRENT_SITE', '/');
define('SITE_ID_CURRENT_SITE', 1);
define('BLOG_ID_CURRENT_SITE', 1);
define('COOKIE_DOMAIN', '.{primary_domain}');

'''
            config_content = config_content.replace(
                "/* That's all, stop editing!",
                additional_config + "/* That's all, stop editing!"
            )
            
            with open(wp_config_path, 'w') as f:
                f.write(config_content)
        
        # Set permissions
        print("Setting permissions...")
        for root, dirs, files in os.walk(wordpress_dir):
            for d in dirs:
                os.chmod(os.path.join(root, d), 0o755)
            for f in files:
                os.chmod(os.path.join(root, f), 0o644)
        
        # Cleanup
        print("Cleaning up...")
        os.remove(tmp_file)
        shutil.rmtree('/tmp/wordpress', ignore_errors=True)
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'WordPress deployed successfully',
                'path': wordpress_dir,
                'action': 'deployed'
            })
        }
        
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': f'Error deploying WordPress: {str(e)}',
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
