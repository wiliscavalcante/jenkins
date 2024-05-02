import os
import subprocess
import datetime
import boto3
import shutil
from tqdm import tqdm

# Configuração usando variáveis de ambiente
PVC_DIRECTORY = os.environ.get('PVC_DIRECTORY', '/app/pvc')
TEMP_DIRECTORY = os.environ.get('TEMP_DIRECTORY', '/app/temp')
S3_BUCKET = os.environ.get('S3_BUCKET', 'default-bucket')
s3 = boto3.client('s3')

# Função para execução de comandos do sistema
def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, stderr = process.communicate()
    return stdout.decode('utf-8'), stderr.decode('utf-8')

# Função para converter uma data ISO em timestamp
def get_timestamp(iso_date):
    try:
        date_obj = datetime.datetime.strptime(iso_date, '%Y-%m-%dT%H:%M:%S+00:00')
        timestamp = int(date_obj.timestamp())
        return timestamp
    except ValueError:
        try:
            date_obj = datetime.datetime.strptime(iso_date, '%Y-%m-%dT%H')
            timestamp = int(date_obj.timestamp())
            return timestamp
        except ValueError:
            print(f"Erro: data inválida no formato: '{iso_date}'. Esperado '%Y-%m-%dT%H:%M:%S+00:00'.")
            return None

# Função para baixar arquivos do S3 com barra de progresso
def download_with_progress(bucket, key, filename):
    s3 = boto3.resource('s3')
    meta_data = s3.meta.client.head_object(Bucket=bucket, Key=key)
    total_size = int(meta_data.get('ContentLength', 0))
    progress = tqdm(total=total_size, unit='B', unit_scale=True, desc=filename)

    def callback(bytes_transferred):
        progress.update(bytes_transferred)

    s3.meta.client.download_file(bucket, key, filename, Callback=callback)
    progress.close()

# Listando objetos do bucket S3 e identificando pastas DAG
response = s3.list_objects_v2(Bucket=S3_BUCKET)
s3_folders = set()
for content in response.get('Contents', []):
    s3_folders.add(content['Key'].split('/')[0])

# Para cada pasta identificada, verifica se há atualizações e baixa se necessário
for folder in s3_folders:
    s3_file = f"{folder}/{folder}.zip"
    local_file = f"{TEMP_DIRECTORY}/{folder}.zip"
    pvc_folder = f"{PVC_DIRECTORY}/{folder}"

    # Obtém a hora da última modificação do arquivo no S3
    response = s3.head_object(Bucket=S3_BUCKET, Key=s3_file)
    s3_time = response['LastModified']
    s3_seconds = get_timestamp(s3_time.strftime('%Y-%m-%dT%H:%M:%S+00:00'))

    if s3_seconds is None:
        continue

    # Compara a hora da última modificação com o arquivo local, se existir
    recorded_time = None
    if os.path.exists(pvc_folder):
        recorded_time = os.path.getmtime(pvc_folder)
    recorded_seconds = recorded_time if recorded_time else 0

    # Se o arquivo do S3 for mais recente, ou a pasta DAG não existir, realiza o download
    if s3_seconds > recorded_seconds or not os.path.exists(pvc_folder):
        print(f"Baixando s3://{S3_BUCKET}/{s3_file} para {local_file}.")
        try:
            download_with_progress(S3_BUCKET, s3_file, local_file)
            print(f"Download bem-sucedido de s3://{S3_BUCKET}/{s3_file}.")

            # Descompacta o arquivo e remove o zip
            if os.path.exists(pvc_folder):
                shutil.rmtree(pvc_folder)
            os.makedirs(pvc_folder, exist_ok=True)
            unzip_command = f"unzip -q {local_file} -d {pvc_folder}"
            os.system(unzip_command)
            os.remove(local_file)
            os.utime(pvc_folder, (s3_seconds, s3_seconds))

        except Exception as e:
            print(f"Erro ao baixar s3://{S3_BUCKET}/{s3_file}. Erro: {e}")

    else:
        print(f"O arquivo s3://{S3_BUCKET}/{s3_file} não foi modificado. Pulando o download.")

print("Sincronização completa.")

