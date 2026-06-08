locals {
  # FIFO 큐는 이름이 .fifo 로 끝나야 함
  base_name = "${var.project_name}-${var.environment}-${var.name}"
}

# 처리 실패 메시지 보관용 DLQ (FIFO 큐의 DLQ 도 FIFO 여야 함)
resource "aws_sqs_queue" "dlq" {
  name                        = "${local.base_name}-dlq.fifo"
  fifo_queue                  = true
  content_based_deduplication = var.content_based_deduplication
  message_retention_seconds   = var.dlq_message_retention_seconds
  sqs_managed_sse_enabled     = true
}

# 예약 데이터 임시 저장 FIFO 큐
# 서비스 produce → persistence 람다 consume → reservation DB 적재 (쓰기 평탄화)
resource "aws_sqs_queue" "this" {
  name                        = "${local.base_name}.fifo"
  fifo_queue                  = true
  content_based_deduplication = var.content_based_deduplication
  visibility_timeout_seconds  = var.visibility_timeout_seconds
  message_retention_seconds   = var.message_retention_seconds
  sqs_managed_sse_enabled     = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = var.max_receive_count
  })
}
