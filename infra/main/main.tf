
provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket         = "tf-state-bucket-luhur"
    key            = "main/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform_lock_main"
  }
}

resource "aws_vpc" "application_vpc" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "application-vpc"
  }
}

resource "aws_subnet" "application_subnet_a" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "application-subnet-a"
  }
}

resource "aws_subnet" "application_subnet_b" {
  vpc_id                  = aws_vpc.application_vpc.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = false
  tags = {
    Name = "application-subnet-b"
  }
}


resource "aws_vpc" "landing_zone_vpc" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "landing-zone-vpc"
  }
}

resource "aws_subnet" "landing_zone_subnet_private" {
  vpc_id                  = aws_vpc.landing_zone_vpc.id
  cidr_block              = "192.168.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "landing-zone-private-subnet"
  }
}

resource "aws_subnet" "landing_zone_subnet_public" {
  vpc_id                  = aws_vpc.landing_zone_vpc.id
  cidr_block              = "192.168.2.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = false
  tags = {
    Name = "landing-zone-public-subnet"
  }
}




resource "aws_security_group" "application_security_group" {
  vpc_id = aws_vpc.application_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "application-security-group"
  }
}

resource "aws_security_group" "db_security_group" {
  vpc_id = aws_vpc.application_vpc.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-security-group"
  }
}

resource "aws_security_group" "landing_zone_security_group" {
  vpc_id = aws_vpc.landing_zone_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.10.0.0/16", "192.168.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "landing_zone_security_group"
  }
}

resource "aws_nat_gateway" "landing_zone_ngw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.landing_zone_subnet_public.id
  tags = {
    Name = "landing-zone-ngw"
  }
}

resource "aws_eip" "nat_eip" {
  vpc = true
}



resource "aws_internet_gateway" "landing_zone_igw" {
  vpc_id = aws_vpc.landing_zone_vpc.id

  tags = {
    Name = "landing-zone-igw"
  }
}

resource "aws_ec2_transit_gateway" "transit_gw" {
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"

}

resource "aws_ec2_transit_gateway_vpc_attachment" "landing_zone_vpc_attachment" {

  subnet_ids         = [aws_subnet.landing_zone_subnet_private.id]
  transit_gateway_id = aws_ec2_transit_gateway.transit_gw.id
  vpc_id             = aws_vpc.landing_zone_vpc.id
  tags = {
    "Name" = "transit-gateway-landing-zone-vpc-attachment"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment" "application_vpc_attachment" {

  subnet_ids         = [aws_subnet.application_subnet_a.id, aws_subnet.application_subnet_b.id]
  transit_gateway_id = aws_ec2_transit_gateway.transit_gw.id
  vpc_id             = aws_vpc.application_vpc.id
  tags = {
    "Name" = "transit-gateway-application-vpc-attachment"
  }
}


resource "aws_route_table" "application_route_table" {
  vpc_id = aws_vpc.application_vpc.id
  tags = {
    Name = "Application route table"
  }
}

resource "aws_route_table" "landing_zone_public_route_table" {
  vpc_id = aws_vpc.landing_zone_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.landing_zone_igw.id
  }
  tags = {
    Name = "Landing Zone Public route table"
  }
}


resource "aws_route_table" "landing_zone_private_route_table" {
  vpc_id = aws_vpc.landing_zone_vpc.id
  tags = {
    Name = "Landing Zone Private route table"
  }
}

resource "aws_route" "landing_zone_private_tgw_route" {
  route_table_id         = aws_route_table.landing_zone_private_route_table.id
  destination_cidr_block = "10.10.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gw.id
  depends_on = [
    aws_ec2_transit_gateway.transit_gw
  ]
}

resource "aws_route" "landing_zone_private_nat_route" {
  route_table_id         = aws_route_table.landing_zone_private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.landing_zone_ngw.id
  depends_on = [
    aws_nat_gateway.landing_zone_ngw
  ]
}



resource "aws_route" "application_tgw_route" {
  route_table_id         = aws_route_table.application_route_table.id
  destination_cidr_block = "192.168.0.0/16"
  transit_gateway_id     = aws_ec2_transit_gateway.transit_gw.id
  depends_on = [
    aws_ec2_transit_gateway.transit_gw
  ]
}

resource "aws_route_table_association" "landing_zone_private_route_table_association" {
  subnet_id      = aws_subnet.landing_zone_subnet_private.id
  route_table_id = aws_route_table.landing_zone_private_route_table.id
}

resource "aws_route_table_association" "landing_zone_public_route_table_association" {
  subnet_id      = aws_subnet.landing_zone_subnet_public.id
  route_table_id = aws_route_table.landing_zone_public_route_table.id
}

resource "aws_route_table_association" "application_subnet_a_route_table_association" {
  subnet_id      = aws_subnet.application_subnet_a.id
  route_table_id = aws_route_table.application_route_table.id
}

resource "aws_route_table_association" "application_subnet_b_route_table_association" {
  subnet_id      = aws_subnet.application_subnet_b.id
  route_table_id = aws_route_table.application_route_table.id
}

locals {
  endpoints = {
    "endpoint-ssm" = {
      name = "ssm"
    },
    "endpoint-ssmm-essages" = {
      name = "ssmmessages"
    },
    "endpoint-ec2-messages" = {
      name = "ec2messages"
    }
  }
}


resource "aws_vpc_endpoint" "landing_zone_endpoints" {
  vpc_id             = aws_vpc.landing_zone_vpc.id
  for_each           = local.endpoints
  vpc_endpoint_type  = "Interface"
  service_name       = "com.amazonaws.ap-southeast-1.${each.value.name}"
  security_group_ids = [aws_security_group.landing_zone_security_group.id]
}

resource "aws_vpc_endpoint" "application_vpc_execute_api_endpoint" {
  service_name        = "com.amazonaws.ap-southeast-1.execute-api"
  vpc_id              = aws_vpc.application_vpc.id
  subnet_ids          = [aws_subnet.application_subnet_a.id, aws_subnet.application_subnet_b.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.application_security_group.id]
}

resource "aws_vpc_endpoint" "application_vpc_secret_manager_endpoint" {
  service_name        = "com.amazonaws.ap-southeast-1.secretsmanager"
  vpc_id              = aws_vpc.application_vpc.id
  subnet_ids          = [aws_subnet.application_subnet_a.id, aws_subnet.application_subnet_b.id]
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids  = [aws_security_group.application_security_group.id]
}

resource "aws_lambda_permission" "lambda_permission" {
  action        = "lambda:InvokeFunction"
  function_name = "nodejs_function"
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.nodejs_api.execution_arn}/*/*/*"

  depends_on = [aws_lambda_function.nodejs_function]
}

resource "aws_lambda_function" "nodejs_function" {
  filename         = "apps.zip"
  function_name    = "nodejs_function"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "index.handler"
  source_code_hash = filebase64sha256("apps.zip")
  runtime          = "nodejs14.x"

  environment {
    variables = {

    }
  }

  vpc_config {
    subnet_ids         = [aws_subnet.application_subnet_a.id, aws_subnet.application_subnet_b.id]
    security_group_ids = [aws_security_group.application_security_group.id]
  }
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "lambda-policy"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  inline_policy {
    name = "lambda-secrets-manager-permissions"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret",
        "secretsmanager:ListSecrets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
  }

  inline_policy {
    name = "lambda-ec2-permissions"

    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    { 
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": "*"
    }
  ]
}
EOF
  }
}

resource "aws_api_gateway_rest_api_policy" "api_gateway_policy" {
  rest_api_id = aws_api_gateway_rest_api.nodejs_api.id

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": "*",
        "Action": "execute-api:Invoke",
        "Resource": [
          "execute-api:/*"
        ]
      },
      {
        "Effect": "Deny",
        "Principal": "*",
        "Action": "execute-api:Invoke",
        "Resource": [
          "execute-api:/*"
        ],
        "Condition" : {
          "StringNotEquals": {
            "aws:SourceVpce": "${aws_vpc_endpoint.application_vpc_execute_api_endpoint.id}"
          }
        }
      }
    ]
  }
EOF
}

resource "aws_api_gateway_rest_api" "nodejs_api" {
  name = "node_js_api"
  endpoint_configuration {
    types = [
    "PRIVATE"]
    vpc_endpoint_ids = [aws_vpc_endpoint.application_vpc_execute_api_endpoint.id]
  }
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.nodejs_api.id
  parent_id   = aws_api_gateway_rest_api.nodejs_api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = aws_api_gateway_rest_api.nodejs_api.id
  resource_id   = aws_api_gateway_resource.proxy.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "nodejs_api" {
  rest_api_id = aws_api_gateway_rest_api.nodejs_api.id
  resource_id = aws_api_gateway_method.proxy.resource_id
  http_method = aws_api_gateway_method.proxy.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.nodejs_function.invoke_arn
}

resource "aws_api_gateway_deployment" "api_gateway_deployment" {
  rest_api_id = aws_api_gateway_rest_api.nodejs_api.id
  stage_name  = "dev"
  depends_on  = [aws_api_gateway_integration.nodejs_api]
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db-subnet-group"
  subnet_ids = [aws_subnet.application_subnet_a.id, aws_subnet.application_subnet_b.id]
}

resource "aws_db_instance" "rds_db" {
  identifier             = "rds-db"
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "<DB_USER>"
  password               = "<DB_PASS>"
  db_name                = "<DB_NAME>"
  parameter_group_name   = "default.mysql5.7"
  skip_final_snapshot    = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_security_group.id]

  tags = {
    Name = "rds-db-instance"
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "EC2_SSM_Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2_SSM_Instance_Profile"

  role = aws_iam_role.ec2_role.name
}

data "aws_ami" "amazon_linux_2_ssm" {
  most_recent = true

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "tester_instance" {
  ami                    = data.aws_ami.amazon_linux_2_ssm.id
  instance_type          = "t2.micro"
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
  subnet_id              = aws_subnet.landing_zone_subnet_private.id
  vpc_security_group_ids = [aws_security_group.landing_zone_security_group.id]

  tags = {
    Name = "tester-instance"
  }
}

output "db_host" {
  value = aws_db_instance.rds_db.endpoint
}

output "application_vpc_execute_api_endpoint_id" {
  value = aws_vpc_endpoint.application_vpc_execute_api_endpoint.id
}

output "api_gateway_id" {
  value = aws_api_gateway_rest_api.nodejs_api.id
}

output "ec2_id" {
  value = aws_instance.tester_instance.id
}

output "base_uri" {
  value = "https://${aws_api_gateway_rest_api.nodejs_api.id}-${aws_vpc_endpoint.application_vpc_execute_api_endpoint.id}.execute-api.ap-southeast-1.amazonaws.com/dev/"
}
