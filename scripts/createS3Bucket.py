import argparse
import boto3


def check_s3_bucket_exists(bucket_name, s3_client):
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        return True
    except s3_client.exceptions.NoSuchBucket:
        return False


def create_s3_bucket(bucket_name):
    region = 'ap-southeast-1'
    s3 = boto3.client('s3', region_name=region)
    if check_s3_bucket_exists(bucket_name, s3):
        print(f"S3 bucket '{bucket_name}' already exists.")
    else:
        s3.create_bucket(Bucket=bucket_name)
        print(f"S3 bucket '{bucket_name}' created.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    create_s3_bucket(args.name)
