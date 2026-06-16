output "bastion_public_ip" {
  description = "Bastion 퍼블릭 IP"
  value       = aws_instance.bastion.public_ip
}
