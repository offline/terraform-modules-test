resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  version    = "3.12.1"
  chart      = "metrics-server"
  namespace  = "kube-system"

  set {
    name  = "tolerations[0].key"
    value = "CriticalAddonsOnly"
  }

  set {
    name  = "tolerations[0].operator"
    value = "Exists"
  }
}


resource "kubernetes_horizontal_pod_autoscaler_v2" "adserver" {
  metadata {
    name = "adserver-autoscale"
  }

  spec {
    min_replicas = 1
    max_replicas = 3

    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = "adserver"
    }

    behavior {
      scale_up {
        stabilization_window_seconds = 90
        select_policy                = "Max"
        policy {
          period_seconds = 30
          type           = "Pods"
          value          = 1
        }
        policy {
          period_seconds = 30
          type           = "Percent"
          value          = 10
        }
      }

      scale_down {
        stabilization_window_seconds = 300
        select_policy                = "Min"
        policy {
          period_seconds = 30
          type           = "Pods"
          value          = 1
        }
        policy {
          period_seconds = 30
          type           = "Percent"
          value          = 10
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = "60"
        }
      }
    }
  }
}
