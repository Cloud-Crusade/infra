# ticketing 워크로드를 eks 모듈 밖(workloads)으로 분리 — 주소만 이동(재생성 0)
moved {
  from = module.eks.kubernetes_namespace_v1.ticketing
  to   = module.workloads.kubernetes_namespace_v1.ticketing
}
moved {
  from = module.eks.kubernetes_secret_v1.ticketing_secrets
  to   = module.workloads.kubernetes_secret_v1.ticketing_secrets
}
moved {
  from = module.eks.kubernetes_config_map_v1.ticketing_config
  to   = module.workloads.kubernetes_config_map_v1.ticketing_config
}
moved {
  from = module.eks.kubernetes_service_v1.rds_core_writer
  to   = module.workloads.kubernetes_service_v1.rds_core_writer
}
moved {
  from = module.eks.kubernetes_service_v1.rds_core_reader
  to   = module.workloads.kubernetes_service_v1.rds_core_reader
}
moved {
  from = module.eks.kubernetes_service_v1.rds_reservation_writer
  to   = module.workloads.kubernetes_service_v1.rds_reservation_writer
}
moved {
  from = module.eks.kubernetes_service_v1.rds_reservation_reader
  to   = module.workloads.kubernetes_service_v1.rds_reservation_reader
}
moved {
  from = module.eks.kubernetes_service_v1.redis_main
  to   = module.workloads.kubernetes_service_v1.redis_main
}
moved {
  from = module.eks.aws_iam_role.reservation_irsa
  to   = module.workloads.aws_iam_role.reservation_irsa
}
moved {
  from = module.eks.aws_iam_role_policy.reservation_sqs
  to   = module.workloads.aws_iam_role_policy.reservation_sqs
}
moved {
  from = module.eks.module.ticketing_service
  to   = module.workloads.module.ticketing_service
}
moved {
  from = module.eks.random_password.db_role
  to   = module.workloads.random_password.db_role
}
moved {
  from = module.eks.kubernetes_secret_v1.ticketing_db
  to   = module.workloads.kubernetes_secret_v1.ticketing_db
}
moved {
  from = module.eks.kubernetes_secret_v1.db_bootstrap
  to   = module.workloads.kubernetes_secret_v1.db_bootstrap
}
moved {
  from = module.eks.kubernetes_config_map_v1.db_bootstrap_sql
  to   = module.workloads.kubernetes_config_map_v1.db_bootstrap_sql
}
moved {
  from = module.eks.kubernetes_job_v1.db_bootstrap
  to   = module.workloads.kubernetes_job_v1.db_bootstrap
}
moved {
  from = module.eks.kubernetes_job_v1.migrate
  to   = module.workloads.kubernetes_job_v1.migrate
}
