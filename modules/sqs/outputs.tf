output "queue_arn" {
  description = "큐 ARN (consumer event source / producer 권한용)"
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "큐 URL (메시지 송수신)"
  value       = aws_sqs_queue.this.url
}

output "queue_name" {
  description = "큐 이름"
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "DLQ ARN"
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "DLQ URL"
  value       = aws_sqs_queue.dlq.url
}
