output "jenkins_instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.web_server.id
}

output "jenkins_instance_public_ip_Address" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web_server.public_ip
}