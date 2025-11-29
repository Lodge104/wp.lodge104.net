output "application_name" {
  description = "Name of the Elastic Beanstalk application"
  value       = aws_elastic_beanstalk_application.wordpress.name
}

output "environment_name" {
  description = "Name of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.wordpress.name
}

output "environment_id" {
  description = "ID of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.wordpress.id
}

output "endpoint_url" {
  description = "CNAME of the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.wordpress.cname
}

output "load_balancer_url" {
  description = "Load balancer URL for the Elastic Beanstalk environment"
  value       = aws_elastic_beanstalk_environment.wordpress.endpoint_url
}

output "autoscaling_groups" {
  description = "Auto Scaling groups associated with the environment"
  value       = aws_elastic_beanstalk_environment.wordpress.autoscaling_groups
}

output "instances" {
  description = "EC2 instances in the environment"
  value       = aws_elastic_beanstalk_environment.wordpress.instances
}

output "load_balancers" {
  description = "Load balancers associated with the environment"
  value       = aws_elastic_beanstalk_environment.wordpress.load_balancers
}
