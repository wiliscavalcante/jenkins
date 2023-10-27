resource "kubernetes_cron_job" "dag_sync_cron_job" {
  metadata {
    name      = "dag-sync-cron-job"
    namespace = "seu-namespace" # Substitua pelo seu namespace
  }

  spec {
    concurrency_policy                  = "Replace"
    failed_jobs_history_limit           = 1
    successful_jobs_history_limit       = 3
    starting_deadline_seconds           = 3600
    schedule                            = "*/2 * * * *"

    job_template {
      metadata {}
      spec {
        backoff_limit = 3

        template {
          metadata {}
          spec {
            container {
              name  = "dag-sync"
              image = "SEU_REGISTRO/SEU_IMAGEM:TAG" # Substitua pelo caminho da sua imagem Docker

              env {
                name  = "BUCKET_NAME"
                value = "nome-do-seu-bucket" # Substitua pelo nome do seu bucket
              }
              env {
                name  = "LOCAL_TEMP_DIR"
                value = "/tmp"
              }
              env {
                name  = "PVC_DIR"
                value = "/data"
              }

              volume_mount {
                name       = "pvc-storage"
                mount_path = "/data"
              }
            }
            restart_policy = "OnFailure"
            service_account_name = "airflow-sa"

            volume {
              name = "pvc-storage"

              persistent_volume_claim {
                claim_name = "nome-do-seu-pvc" # Substitua pelo nome do seu PVC
              }
            }
          }
        }
      }
    }
  }
}
