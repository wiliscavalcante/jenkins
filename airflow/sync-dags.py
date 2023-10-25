import os
import subprocess
import datetime
import boto3
import shutil
from tqdm import tqdm

PVC_DIRECTORY = '/home/ubuntu/projetos/airflow/pvc'
TEMP_DIRECTORY = '/home/ubuntu/projetos/airflow/temp'
S3_BUCKET = 'infra-teste-be'
s3 = boto3.client('s3')

def run_command(command):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
    stdout, stderr = process.communicate()
    return stdout.decode('utf-8'), stderr.decode('utf-8')

def get_timestamp(iso_date):
    try:
        date_obj = datetime.datetime.strptime(iso_date, '%Y-%m-%dT%H:%M:%S+00:00')
        timestamp = int(date_obj.timestamp())
        return timestamp
    except ValueError:
        try:
            # Tentativa de aceitar a variação de formato
            date_obj = datetime.datetime.strptime(iso_date, '%Y-%m-%dT%H')
            timestamp = int(date_obj.timestamp())
            return timestamp
        except ValueError:
            print(f"\nErro: data inválida no formato: '{iso_date}'. O formato esperado é '%Y-%m-%dT%H:%M:%S+00:00'.")
            return None

def download_with_progress(bucket, key, filename):
    s3 = boto3.resource('s3')
    meta_data = s3.meta.client.head_object(Bucket=bucket, Key=key)
    total_size = int(meta_data.get('ContentLength', 0))
    progress = tqdm(total=total_size, unit='B', unit_scale=True, desc=filename)

    def callback(bytes_transferred):
        progress.update(bytes_transferred)

    s3.meta.client.download_file(bucket, key, filename, Callback=callback)
    progress.close()

response = s3.list_objects_v2(Bucket=S3_BUCKET)
s3_folders = set()
for content in response.get('Contents', []):
    s3_folders.add(content['Key'].split('/')[0])

for folder in s3_folders:
    s3_file = f"{folder}/{folder}.zip"
    local_file = f"{TEMP_DIRECTORY}/{folder}.zip"
    pvc_folder = f"{PVC_DIRECTORY}/{folder}"

    response = s3.head_object(Bucket=S3_BUCKET, Key=s3_file)
    s3_time = response['LastModified']
    s3_seconds = get_timestamp(s3_time.strftime('%Y-%m-%dT%H:%M:%S+00:00'))

    if s3_seconds is None:
        continue

    recorded_time = None
    if os.path.exists(pvc_folder):
        recorded_time = os.path.getmtime(pvc_folder)
    recorded_seconds = recorded_time if recorded_time else 0

    if s3_seconds > recorded_seconds or not os.path.exists(pvc_folder):
        print(f"\nBaixando s3://{S3_BUCKET}/{s3_file} para {local_file}.")
        try:
            download_with_progress(S3_BUCKET, s3_file, local_file)
            print(f"\nDownload bem-sucedido de s3://{S3_BUCKET}/{s3_file}.")

            if os.path.exists(pvc_folder):
                shutil.rmtree(pvc_folder)
            os.makedirs(pvc_folder, exist_ok=True)
            unzip_command = f"unzip -q {local_file} -d {pvc_folder}"
            os.system(unzip_command)

            # Remover o arquivo .zip após a descompactação
            try:
                os.remove(local_file)
            except OSError as e:
                print(f"Erro ao remover {local_file}. Erro: {e.strerror}")

            os.utime(pvc_folder, (s3_seconds, s3_seconds))

        except Exception as e:
            print(f"\nErro ao baixar s3://{S3_BUCKET}/{s3_file}. Erro: {e}")

    else:
        print(f"\nO arquivo s3://{S3_BUCKET}/{s3_file} não foi modificado. Pulando o download.")

print("\nSincronização completa.")
