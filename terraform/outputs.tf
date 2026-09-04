output "vpc_id" {
  description = "ID of the project VPC."
  value       = aws_vpc.main.id
}

output "ec2_instance_id" {
  description = "ID of the deployed web server."
  value       = aws_instance.web.id
}

output "web_server_public_ip" {
  description = "Public IP address of the web server."
  value       = aws_instance.web.public_ip
}

output "web_server_url" {
  description = "HTTP URL for validating the automated deployment."
  value       = "http://${aws_instance.web.public_ip}"
}
