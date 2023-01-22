terraform {
  backend "remote" {
    organization = "dot"

    workspaces {
      name = "dot-ci-cd"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.48"
    }
  }

  required_version = ">= 0.15.0"
}

provider "aws" {
  profile = "default"
  region  = "eu-west-1"
}

variable "public_key" {
  description = "ec2 environment public key value"
  type        = string
}

variable "BUCKET_ID" {
  description = "Id used for naming the bucket"
  type        = string
}

variable "base_ami_id" {
  description = "Base AMI ID"
  type        = string
}

# Create VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "dot-vpc"
  }
}

# Create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  
  tags = {
    Name        = "dot-igw"
  }
}

# Create  public subnet
resource "aws_subnet" "dot-public_subnet" {
  vpc_id     = aws_vpc.vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "dot-public-subnet"
  }
}

resource "aws_key_pair" "dot_server_key" {
  key_name   = "dot_server_key"
  public_key = var.dot_server_public_key

  tags = {
    "Name" = "dot_server_public_key"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.dot_server.id
  allocation_id = aws_eip.dot-eip.id
}

resource "aws_instance" "dot_server" {
  ami                    = var.base_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["sg-0d2411db69a112a30"]
  key_name               = aws_key_pair.dot_server_key.key_name
  subnet_id              = aws_subnet.dot-public_subnet.id

  tags = {
    "Name" = "dot_server"
  }
}

resource "aws_eip" "dot-eip" {
  vpc = true
}

resource "aws_s3_bucket" "dot-bucket" {
  bucket = "dot-var.BUCKET_ID"
  acl    = "public-read"
  policy = file("policy.json")

  website {
    index_document = "index.html"
    error_document = "error.html"

    routing_rules = <<EOF
[{
    "Condition": {
        "KeyPrefixEquals": "docs/"
    },
    "Redirect": {
        "ReplaceKeyPrefixWith": "documents/"
    }
}]
EOF
  }
}

output "dot_server_dns" {
  value = aws_instance.dot_server.public_dns
}
output "dot_bucket_id" {
  value = aws_s3_bucket.dot-bucket.id
}
output "dot_bucket_domain_name" {
  value = aws_s3_bucket.dot-bucket.bucket_domain_name 
}
output "dot_bucket_website_endpoint" {
  value = aws_s3_bucket.dot-bucket.website_endpoint 
}