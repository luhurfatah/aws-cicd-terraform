import boto3
from botocore.exceptions import ClientError
import json
import argparse


def get_secret(group, key):
    secret_name = "test-secret"
    region_name = "ap-southeast-1"
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name=region_name
    )

    try:
        get_secret_value_response = client.get_secret_value(
            SecretId=secret_name
        )
    except ClientError as e:
        print(f"Error retrieving secret: {e}")
        return None

    secret_value = json.loads(get_secret_value_response['SecretString'])
    for k, v in secret_value[group].items():
        if (k == key):
            print(v)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", required=True)
    parser.add_argument("--key", required=True)

    args = parser.parse_args()
    group = args.group
    key = args.key

    get_secret(group, key)
