provider "aws" {
  region = "ap-southeast-1"
}

terraform {
  backend "s3" {
    bucket         = "tf-state-bucket-luhur"
    key            = "support/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "terraform_lock_support"
  }
}


resource "aws_secretsmanager_secret" "lfsecret" {
  name = "lfsecret"
}

resource "aws_secretsmanager_secret_version" "example_secret_version" {
  secret_id     = aws_secretsmanager_secret.lfsecret.id
  secret_string = <<EOT
{
  "db_credentials": {
    "db_host" : "<DB_HOST>",
    "username": "<DB_USER>",
    "password": "<DB_PASS>",
    "db_name" : "<DB_NAME>"
  }
}
EOT
}


resource "aws_codecommit_repository" "app_repo" {
  repository_name = "application-repo"
}

resource "aws_iam_role" "role_for_codebuild" {
  name = "codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codebuild.amazonaws.com",
      },
    }],
  })
}


resource "aws_iam_role" "role_for_pipeline" {
  name = "pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "codepipeline.amazonaws.com",
      },
    }],
  })
}


resource "aws_iam_role_policy_attachment" "pipeline_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodePipeline_FullAccess"
  role       = aws_iam_role.role_for_pipeline.name
}

resource "aws_iam_role_policy_attachment" "pipeline_policy_codecommit" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitFullAccess"
  role       = aws_iam_role.role_for_pipeline.name
}

resource "aws_iam_role_policy_attachment" "pipeline_policy_codebuild" {
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeBuildAdminAccess"
  role       = aws_iam_role.role_for_pipeline.name
}

resource "aws_iam_role_policy_attachment" "pipeline_policy_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.role_for_pipeline.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_s3" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_ec2" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_lambda" {
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_apigateway" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_rds" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_dynamodb" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_iam" {
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy_attachment" "codebuild_policy_secretsmanager" {
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
  role       = aws_iam_role.role_for_codebuild.name
}

resource "aws_iam_role_policy" "combined_policy" {
  name = "combined-policy"
  role = aws_iam_role.role_for_codebuild.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets",
        ],
        Resource = "*",
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "*",
      },
    ],
  })
}



resource "aws_codebuild_project" "app_build_deploy" {
  name = "app-build-deploy"
  source {
    type = "CODEPIPELINE"
  }
  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/standard:4.0"
    type         = "LINUX_CONTAINER"

    environment_variable {
      name  = "SECRET_NAME"
      value = "<SECRET_NAME>"
    }

  }
  service_role = aws_iam_role.role_for_codebuild.arn
}


resource "aws_codepipeline" "my_pipeline" {
  name     = "my-pipeline"
  role_arn = aws_iam_role.role_for_pipeline.arn

  artifact_store {
    location = aws_s3_bucket.artifacts_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "SourceAction"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        RepositoryName = aws_codecommit_repository.app_repo.repository_name
        BranchName     = "main"
      }
    }
  }

  stage {
    name = "BuildDeploy"

    action {
      name            = "BuildAndDeployAction"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]

      configuration = {
        ProjectName = aws_codebuild_project.app_build_deploy.name
      }
    }
  }
}


resource "aws_s3_bucket" "artifacts_bucket" {
  bucket = "lzy-artifacts-bucket"
}

resource "aws_s3_bucket_ownership_controls" "artifacts_bucket" {
  bucket = aws_s3_bucket.artifacts_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "artifacts_bucket" {
  depends_on = [aws_s3_bucket_ownership_controls.artifacts_bucket]

  bucket = aws_s3_bucket.artifacts_bucket.id
  acl    = "private"
}

resource "aws_ecr_repository" "private_ecr_repo" {
  name                 = "private-ecr-repo"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  lifecycle {
    prevent_destroy = true
  }
}


output "repo_url" {
  value = aws_codecommit_repository.app_repo.clone_url_http
}

output "private_ecr_repository_url" {
  value = aws_ecr_repository.private_ecr_repo.repository_url
}
