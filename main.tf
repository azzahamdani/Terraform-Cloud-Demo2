# --------------------------------------------#
# Provider AWS
# --------------------------------------------#

terraform {
  required_version = "~> 1.1.7"
  required_providers {
    aws = {
      version = "~> 4.8.0"
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
    bucket         = "terraform-state-demo-002-04042022"
    key            = "terra-backend/terraform.tfstate"
    encrypt        = true
    region         = "us-east-1"
    dynamodb_table = "terraform-state-locking"
  }
}

provider "aws" {
  region  = "us-east-1"
  profile = "default"
}

# --------------------------------------------#
# Remote Backend Component
# --------------------------------------------#

resource "aws_s3_bucket" "tf_remote_state" {
  bucket = "terraform-state-demo-002-04042022"
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning so we can see the full revision history of state files
resource "aws_s3_bucket_versioning" "terraform-state-versioning" {
  bucket = aws_s3_bucket.tf_remote_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable server-side encryption by default
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform-state-sse-rule" {
  bucket = aws_s3_bucket.tf_remote_state.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# DynamoDB for locking the state file
resource "aws_dynamodb_table" "tf_state_locking" {
  hash_key = "LockID"
  name     = "terraform-state-locking"
  attribute {
    name = "LockID"
    type = "S"
  }
  billing_mode = "PAY_PER_REQUEST"
}

# --------------------------------------------#
# EC2 Instance
# --------------------------------------------#

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "ubuntu" {
  count         = 2
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  tags = {
    Name = var.instance_name
  }
}