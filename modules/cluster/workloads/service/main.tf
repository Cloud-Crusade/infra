locals {
  labels = { app = "ticketing-${var.name}" }
}

resource "kubernetes_service_account_v1" "this" {
  metadata {
    name      = "ticketing-${var.name}"
    namespace = var.namespace
    annotations = var.irsa_role_arn == "" ? {} : {
      "eks.amazonaws.com/role-arn" = var.irsa_role_arn
    }
  }
}

resource "kubernetes_deployment_v1" "this" {
  wait_for_rollout = false

  metadata {
    name      = "ticketing-${var.name}"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    replicas = var.replicas

    selector {
      match_labels = local.labels
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    template {
      metadata {
        labels = local.labels
      }
      spec {
        service_account_name             = kubernetes_service_account_v1.this.metadata[0].name
        termination_grace_period_seconds = 30

        toleration {
          key      = "dedicated"
          value    = "app"
          operator = "Equal"
          effect   = "NoSchedule"
        }
        node_selector = { role = "app" }

        security_context {
          run_as_non_root = true
          run_as_user     = 10001
        }

        container {
          name  = "app"
          image = var.image

          port {
            name           = "http"
            container_port = var.http_port
          }

          dynamic "port" {
            for_each = var.grpc_enabled ? [1] : []
            content {
              name           = "grpc"
              container_port = var.grpc_port
            }
          }

          dynamic "env_from" {
            for_each = var.config_map_refs
            content {
              config_map_ref { name = env_from.value }
            }
          }
          dynamic "env_from" {
            for_each = var.secret_refs
            content {
              secret_ref { name = env_from.value }
            }
          }
          dynamic "env" {
            for_each = var.extra_env
            content {
              name  = env.key
              value = env.value
            }
          }

          security_context {
            allow_privilege_escalation = false
          }

          liveness_probe {
            http_get {
              path = "/healthz"
              port = var.http_port
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }
          readiness_probe {
            http_get {
              path = "/readyz"
              port = var.http_port
            }
            initial_delay_seconds = 5
            period_seconds        = 5
            failure_threshold     = 3
          }

          resources {
            requests = {
              cpu    = var.cpu_request
              memory = var.memory_request
            }
            limits = {
              cpu    = var.cpu_limit
              memory = var.memory_limit
            }
          }

          lifecycle {
            pre_stop {
              exec {
                command = ["/bin/sh", "-c", "sleep 5"]
              }
            }
          }
        }
      }
    }
  }

  # replicas 는 HPA, image 는 cc/app CD(kubectl set image) 가 소유 → terraform 드리프트 회피
  lifecycle {
    ignore_changes = [
      spec[0].replicas,
      spec[0].template[0].spec[0].container[0].image,
    ]
  }
}

# HTTP(ClusterIP) — NLB·내부 DNS 가 바인딩
resource "kubernetes_service_v1" "http" {
  metadata {
    name      = "ticketing-${var.name}"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    selector = local.labels
    port {
      name        = "http"
      port        = var.http_port
      target_port = var.http_port
    }
  }
}

# gRPC headless — clusterIP None 으로 pod 마다 DNS A 레코드 → dns:/// round_robin 풀링
resource "kubernetes_service_v1" "grpc" {
  count = var.grpc_enabled ? 1 : 0
  metadata {
    name      = "${var.name}-grpc"
    namespace = var.namespace
    labels    = local.labels
  }
  spec {
    selector   = local.labels
    cluster_ip = "None"
    port {
      name        = "grpc"
      port        = var.grpc_port
      target_port = var.grpc_port
    }
  }
}

resource "kubernetes_horizontal_pod_autoscaler_v2" "this" {
  metadata {
    name      = "ticketing-${var.name}"
    namespace = var.namespace
  }
  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment_v1.this.metadata[0].name
    }
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 60
        }
      }
    }
    # 메모리 메트릭은 opt-in — Python 런타임 특성상 사용률이 떨어지지 않아 scale-in 을 막음
    dynamic "metric" {
      for_each = var.enable_memory_autoscaling ? [1] : []
      content {
        type = "Resource"
        resource {
          name = "memory"
          target {
            type                = "Utilization"
            average_utilization = 70
          }
        }
      }
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 0
        policy {
          type           = "Percent"
          value          = 100
          period_seconds = 30
        }
      }
      scale_down {
        stabilization_window_seconds = 300
        policy {
          type           = "Percent"
          value          = 50
          period_seconds = 60
        }
      }
    }
  }
}
