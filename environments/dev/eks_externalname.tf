# 엔드포인트 컷오버 대비 — 앱은 아래 고정 서비스명을 DB/Redis 호스트로 사용하고,
# 실제 RDS/ElastiCache 가 바뀌면 ExternalName 타깃만 갱신(앱 env·재시작 불필요).
resource "kubernetes_service_v1" "rds_core_writer" {
  metadata {
    name      = "rds-core-writer"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_core_writer_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing, module.rds]
}

resource "kubernetes_service_v1" "rds_core_reader" {
  metadata {
    name      = "rds-core-reader"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_core_reader_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing, module.rds]
}

resource "kubernetes_service_v1" "rds_reservation_writer" {
  metadata {
    name      = "rds-reservation-writer"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_reservation_writer_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing, module.rds]
}

resource "kubernetes_service_v1" "rds_reservation_reader" {
  metadata {
    name      = "rds-reservation-reader"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.db_reservation_reader_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing, module.rds]
}

resource "kubernetes_service_v1" "redis_main" {
  metadata {
    name      = "redis-main"
    namespace = local.ticketing_namespace
  }
  spec {
    type          = "ExternalName"
    external_name = local.redis_main_host
  }
  depends_on = [kubernetes_namespace_v1.ticketing, module.elasticache]
}
