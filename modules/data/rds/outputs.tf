output "primary_endpoint" {
  value = aws_db_instance.primary.endpoint
}

output "primary_identifier" {
  value = aws_db_instance.primary.identifier
}

output "primary_replica_endpoint" {
  value = aws_db_instance.primary_replica.endpoint
}

output "reservation_endpoint" {
  value = aws_db_instance.reservation.endpoint
}

output "reservation_identifier" {
  value = aws_db_instance.reservation.identifier
}

output "reservation_replica_endpoint" {
  value = aws_db_instance.reservation_replica.endpoint
}

output "reservation_replica_2_endpoint" {
  value = aws_db_instance.reservation_replica_2.endpoint
}