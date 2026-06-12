output "bastion_sg_id" {
  value = aws_security_group.bastion.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "eks_sg_id" {
  value = aws_security_group.eks.id
}

output "cache_sg_id" {
  value = aws_security_group.cache.id
}

output "lambda_sg_id" {
  value = aws_security_group.lambda.id
}