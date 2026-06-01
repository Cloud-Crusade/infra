output "primary_1_endpoint" {
  value = aws_db_instance.primary_1.endpoint
}

output "replica_1_endpoint" {
  value = aws_db_instance.replica_1.endpoint
}

output "primary_2_endpoint" {
  value = aws_db_instance.primary_2.endpoint
}

output "replica_2a_endpoint" {
  value = aws_db_instance.replica_2a.endpoint
}

output "replica_2b_endpoint" {
  value = aws_db_instance.replica_2b.endpoint
}