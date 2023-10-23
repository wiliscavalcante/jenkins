resource "kubernetes_cron_job" "dag_sync" {
  metadata {
    name      = "dag-sync-cron-job"
    namespace = "seu-namespace" # Substitua pelo seu namespace
  }
  spec {
    schedule = "*/2 * * * *" # A cada 2 minutos

    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = "airflow-sa"
            
            container {
              image = "SEU_REGISTRO/SEU_IMAGEM:TAG" # Substitua pelo caminho da sua imagem Docker
              name  = "dag-sync"

              env {
                name  = "BUCKET_NAME"
                value = "nome-do-seu-bucket-${var.env}" # Utiliza a variável do Terraform
              }

              env {
                name  = "LOCAL_TEMP_DIR"
                value = "/tmp" # O valor padrão que definimos, altere se necessário
              }

              env {
                name  = "PVC_DIR"
                value = "/data" # O valor padrão que definimos, altere se necessário
              }

              # Montar o PVC
              volume_mount {
                name       = "pvc-storage"
                mount_path = "/data"
              }
            }

            # Definir o PVC
            volume {
              name = "pvc-storage"

              persistent_volume_claim {
                claim_name = "nome-do-seu-pvc" # Substitua pelo nome do seu PVC
              }
            }

            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
}
