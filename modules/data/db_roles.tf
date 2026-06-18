# 서비스별 DB 롤 자격증명 — 프록시 auth 에 등록(앱이 롤로 프록시 경유 접속) + cluster 로 전달(앱 URL·bootstrap).
# 롤 비밀번호 생성을 data 레이어에 두는 이유: 프록시 auth(rds_proxy) 와 동일 apply 에서 시크릿을 만들어야 등록 가능.
locals {
  # 서비스 DB 롤 → 소속 프록시(core | reservation)
  svc_role_proxy = {
    auth_svc        = "core"
    event_svc       = "core"
    reservation_svc = "reservation"
    payment_svc     = "reservation"
  }
}

# asyncpg URL 파싱 안정성 위해 special=false
resource "random_password" "svc_role" {
  for_each = local.svc_role_proxy
  length   = 32
  special  = false
}

resource "aws_secretsmanager_secret" "svc_role" {
  for_each = local.svc_role_proxy
  name     = "${var.project_name}-${var.environment}-rds-role-${replace(each.key, "_", "-")}"
}

resource "aws_secretsmanager_secret_version" "svc_role" {
  for_each      = local.svc_role_proxy
  secret_id     = aws_secretsmanager_secret.svc_role[each.key].id
  secret_string = jsonencode({ username = each.key, password = random_password.svc_role[each.key].result })
}
