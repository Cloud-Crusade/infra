# MSA 서비스 이미지 레지스트리 — cc/app ecr-push.yml 가 ticketing-<svc>:SHA·latest push
locals {
  ticketing_services = ["auth", "event", "reservation", "payment"]
}

resource "aws_ecr_repository" "ticketing" {
  for_each = toset(local.ticketing_services)

  name                 = "ticketing-${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# 태그 미부착 이미지 누적 비용 차단
resource "aws_ecr_lifecycle_policy" "ticketing" {
  for_each   = aws_ecr_repository.ticketing
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "expire untagged after 7 days"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = 7
      }
      action = { type = "expire" }
    }]
  })
}
