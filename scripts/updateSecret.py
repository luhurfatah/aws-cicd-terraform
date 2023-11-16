import boto3
from botocore.exceptions import ClientError
import json
import argparse


def update_db_host(group, key, value):
    secret_name = "<SECRET_NAME>"
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
        secret_value = json.loads(get_secret_value_response['SecretString'])
        secret_value[group][key] = value
        client.put_secret_value(
            SecretId=secret_name,
            SecretString=json.dumps(secret_value)
        )

        print("db_host in secret updated successfully.")
    except ClientError as e:
        print(f"Error updating db_host in secret: {e}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--group", required=True)
    parser.add_argument("--key", required=True)
    parser.add_argument("--value", required=True)

    args = parser.parse_args()
    group = args.group
    key = args.key
    value = args.value

    update_db_host(group, key, value)
