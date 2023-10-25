# #!/bin/bash

# # Configurações
# BUCKET_NAME="${BUCKET_NAME}"  # Será injetado como uma variável de ambiente
# S3_DAGS_DIRECTORY="s3://${BUCKET_NAME}/"  # Caminho no S3 para as Dags
# LOCAL_TEMP_DIRECTORY="${LOCAL_TEMP_DIR:-/tmp}"  # Usaremos /tmp padrão para armazenamento temporário
# PVC_DIRECTORY="${PVC_DIR:-/data}"  # Usaremos /data como ponto de montagem padrão para PVC
# TIMESTAMP_FILE="${LOCAL_TEMP_DIRECTORY}/timestamps.txt"  # Arquivo para armazenar timestamps


# #!/bin/bash

# # Configurações
# BUCKET_NAME="infra-teste-be"  # Substitua pelo nome do seu bucket S3
# S3_DAGS_DIRECTORY="s3://${BUCKET_NAME}/"  # Caminho no S3 para as Dags
# LOCAL_TEMP_DIRECTORY="/home/ubuntu/projetos/airflow/temp"  # Substitua pelo caminho do diretório temporário local
# PVC_DIRECTORY="/home/ubuntu/projetos/airflow/pvc"  # Substitua pelo caminho do seu PVC
# TIMESTAMP_FILE="${LOCAL_TEMP_DIRECTORY}/timestamps.txt"  # Arquivo para armazenar timestamps

# # Criar diretórios necessários
# mkdir -p "${LOCAL_TEMP_DIRECTORY}"
# mkdir -p "${PVC_DIRECTORY}"

# # Lista as pastas no bucket S3
# folders=$(aws s3 ls "${S3_DAGS_DIRECTORY}" | awk '{print $2}')

# # Para cada pasta, faça o download do arquivo zip, se for mais recente, e extraia-o
# for folder in $folders; do
#   # Removendo a última barra da pasta, se houver
#   folder=${folder%/}

#   # Construa o caminho do arquivo zip
#   zipfile_path="${S3_DAGS_DIRECTORY}${folder}/${folder}.zip"
#   local_zipfile="${LOCAL_TEMP_DIRECTORY}/${folder}.zip"

#   # Obtém o timestamp do arquivo no S3
#   s3_timestamp=$(aws s3api head-object --bucket "${BUCKET_NAME}" --key "${folder}/${folder}.zip" --query "LastModified" --output text)

#   # Verifica se o arquivo existe no diretório local e obtém seu timestamp
#   local_timestamp=""
#   if [ -f "${local_zipfile}" ]; then
#     local_timestamp=$(stat -c %Y "${local_zipfile}")
#   fi

#   # Verifica se a pasta DAG ainda existe
#   dag_folder_exists="true"
#   if [ ! -d "${PVC_DIRECTORY}/${folder}" ]; then
#       dag_folder_exists="false"
#   fi

#   # Converte os timestamps para segundos desde a época (epoch)
#   s3_seconds=$(date --date="${s3_timestamp}" +%s)
#   local_seconds=$(date --date="${local_timestamp}" +%s)

#   # Lê o timestamp registrado para esta pasta
#   recorded_timestamp=""
#   if grep -q "${folder}:" "${TIMESTAMP_FILE}"; then
#     recorded_timestamp=$(grep "${folder}:" "${TIMESTAMP_FILE}" | cut -d' ' -f2-)
#   fi

#   # Converte o timestamp registrado para segundos desde a época, se existir
#   recorded_seconds=0
#   if [ ! -z "${recorded_timestamp}" ]; then
#     recorded_seconds=$(date --date="${recorded_timestamp}" +%s)
#   fi

#   # Compara os timestamps e faz o download se o arquivo do S3 for mais recente, ou se a pasta DAG não existir
#   if [ "$dag_folder_exists" = "false" ] || [ -z "$recorded_timestamp" ] || [ "$s3_seconds" -gt "$recorded_seconds" ]; then
#     echo "Arquivo no S3 é mais recente, não há registro do arquivo, ou a pasta DAG foi excluída. Baixando ${zipfile_path} para ${local_zipfile}."

#     # Download do arquivo zip do S3
#     if aws s3 cp "${zipfile_path}" "${local_zipfile}"; then
#       echo "Download bem-sucedido de ${zipfile_path}."

#       # Se a pasta DAG existe, exclua
#       if [ -d "${PVC_DIRECTORY}/${folder}" ]; then
#         rm -rf "${PVC_DIRECTORY}/${folder}"
#       fi

#       # Crie uma nova pasta e extraia o conteúdo do zip
#       mkdir -p "${PVC_DIRECTORY}/${folder}"
#       unzip -q "${local_zipfile}" -d "${PVC_DIRECTORY}/${folder}"

#       # Atualiza o arquivo de timestamps
#       sed -i "/${folder}:/d" "${TIMESTAMP_FILE}"  # Remove o registro antigo, se existir
#       echo "${folder}: ${s3_timestamp}" >> "${TIMESTAMP_FILE}"

#       # Remova o arquivo zip do diretório temporário
#       rm -f "${local_zipfile}"
#     else
#       echo "Falha no download de ${zipfile_path}. O arquivo pode não existir ou não estar acessível."
#     fi
#   else
#     echo "Registro indica que o arquivo local é mais recente ou igual ao arquivo no S3 e a pasta DAG existe. Pulando o download para ${folder}."
#   fi
# done

# # Lógica adicional ou operações de limpeza podem ser adicionadas aqui

# echo "Sincronização completa."

#!/bin/bash

export LC_TIME=en_US.UTF-8

# Função para converter o formato da data retornada pelo S3 para um formato mais padrão
function get_timestamp {
    local iso_date="$1"
    date -d "${iso_date}" '+%s'
}

# Testando
timestamp=$(get_timestamp "2023-10-25T03:16:12+00:00")
echo $timestamp

# Configurações
BUCKET_NAME="infra-teste-be"
S3_DAGS_DIRECTORY="s3://${BUCKET_NAME}/"
LOCAL_TEMP_DIRECTORY="/home/ubuntu/projetos/airflow/temp"
PVC_DIRECTORY="/home/ubuntu/projetos/airflow/pvc"
TIMESTAMP_FILE="${LOCAL_TEMP_DIRECTORY}/timestamps.txt"

# Criar diretórios necessários
mkdir -p "${LOCAL_TEMP_DIRECTORY}"
mkdir -p "${PVC_DIRECTORY}"

# Lista as pastas no bucket S3
folders=$(aws s3 ls "${S3_DAGS_DIRECTORY}" | awk '{print $2}')

for folder in $folders; do
  folder=${folder%/}
  zipfile_path="${S3_DAGS_DIRECTORY}${folder}/${folder}.zip"
  local_zipfile="${LOCAL_TEMP_DIRECTORY}/${folder}.zip"

  # Obtém o timestamp do arquivo no S3
  s3_timestamp=$(aws s3api head-object --bucket "${BUCKET_NAME}" --key "${folder}/${folder}.zip" --query "LastModified" --output text)
  s3_seconds=$(get_timestamp "${s3_timestamp}")

  # Verifica se o arquivo existe no diretório local e obtém seu timestamp
  local_timestamp=""
  if [ -f "${local_zipfile}" ]; then
    local_timestamp=$(stat -c %Y "${local_zipfile}")
  fi

  # Verifica se a pasta DAG ainda existe
  dag_folder_exists="true"
  if [ ! -d "${PVC_DIRECTORY}/${folder}" ]; then
      dag_folder_exists="false"
  fi

  # Lê o timestamp registrado para esta pasta
  recorded_timestamp=""
  if grep -q "${folder}:" "${TIMESTAMP_FILE}"; then
    recorded_timestamp=$(grep "${folder}:" "${TIMESTAMP_FILE}" | cut -d' ' -f2-)
  fi

  # Converte o timestamp registrado para segundos desde a época, se existir
  recorded_seconds=0
  if [ ! -z "${recorded_timestamp}" ]; then
    recorded_seconds=$(get_timestamp "${recorded_timestamp}")
  fi

  if [ "$dag_folder_exists" = "false" ] || [ -z "$recorded_timestamp" ] || [ "$s3_seconds" -gt "$recorded_seconds" ]; then
    echo "Arquivo no S3 é mais recente, não há registro do arquivo, ou a pasta DAG foi excluída. Baixando ${zipfile_path} para ${local_zipfile}."

    if aws s3 cp "${zipfile_path}" "${local_zipfile}"; then
      echo "Download bem-sucedido de ${zipfile_path}."

      if [ -d "${PVC_DIRECTORY}/${folder}" ]; then
        rm -rf "${PVC_DIRECTORY}/${folder}"
      fi

      mkdir -p "${PVC_DIRECTORY}/${folder}"
      unzip -q "${local_zipfile}" -d "${PVC_DIRECTORY}/${folder}"

      sed -i "/${folder}:/d" "${TIMESTAMP_FILE}"
      echo "${folder}: ${s3_timestamp}" >> "${TIMESTAMP_FILE}"

      rm -f "${local_zipfile}"
    else
      echo "Falha no download de ${zipfile_path}. O arquivo pode não existir ou não estar acessível."
    fi
  else
    echo "Registro indica que o arquivo local é mais recente ou igual ao arquivo no S3 e a pasta DAG existe. Pulando o download para ${folder}."
  fi
done

echo "Sincronização completa."
