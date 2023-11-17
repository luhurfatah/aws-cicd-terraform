import boto3
import argparse


def create_dynamodb_table(table_name):
    region = 'ap-southeast-1'
    dynamodb = boto3.client('dynamodb', region_name=region)
    try:
        response = dynamodb.describe_table(TableName=table_name)
        print(
            f"Table {table_name} already exists. Status: {response['Table']['TableStatus']}")
    except dynamodb.exceptions.ResourceNotFoundException:
        attribute_definitions = [
            {
                'AttributeName': 'LockID',
                'AttributeType': 'S'
            }
        ]

        key_schema = [
            {
                'AttributeName': 'LockID',
                'KeyType': 'HASH'
            }
        ]

        provisioned_throughput = {
            'ReadCapacityUnits': 5,
            'WriteCapacityUnits': 5
        }
        dynamodb.create_table(
            TableName=table_name,
            AttributeDefinitions=attribute_definitions,
            KeySchema=key_schema,
            ProvisionedThroughput=provisioned_throughput
        )

        print(f"Table {table_name} created.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True)
    args = parser.parse_args()
    name = args.name

    create_dynamodb_table(name)
