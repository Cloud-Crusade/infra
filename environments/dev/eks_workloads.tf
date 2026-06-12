locals {
  ticketing_namespace = "ticketing"

  # DB_*_URL/REDIS_URL 호스트로 쓰는 클러스터 내부 고정 DNS(ExternalName) 의 실제 타깃.
  # RDS 엔드포인트는 host:port 형식이라 포트 분리
  db_core_writer_host        = split(":", module.rds.primary_endpoint)[0]
  db_core_reader_host        = split(":", module.rds.primary_replica_endpoint)[0]
  db_reservation_writer_host = split(":", module.rds.reservation_endpoint)[0]
  db_reservation_reader_host = split(":", module.rds.reservation_replica_endpoint)[0]
  redis_main_host            = module.elasticache.main_cache_endpoint
}

resource "kubernetes_namespace_v1" "ticketing" {
  metadata {
    name = local.ticketing_namespace
  }
}
