output "core_proxy_endpoint" {
  description = "Core DB Proxy 엔드포인트 (호스트명)"
  value       = aws_db_proxy.core.endpoint
}

output "reservation_proxy_endpoint" {
  description = "Reservation DB Proxy 엔드포인트 (호스트명)"
  value       = aws_db_proxy.reservation.endpoint
}
