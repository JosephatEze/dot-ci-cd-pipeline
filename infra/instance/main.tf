terraform {
  backend "remote" {
    organization = "dot-test"

    workspaces {
      name = "dot-ci-cd-1"
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

resource "aws_eip" "dot-eip" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.dot_server.id
  allocation_id = aws_eip.dot-eip.id
}

resource "aws_s3_bucket" "dot-bucket" {
  bucket = var.BUCKET_ID
  acl    = "public-read"
 

  website {
    index_document = "index.html"
    error_document = "error.html"
  }
}

resource "aws_s3_bucket_policy" "public_read_access" {
  bucket = aws_s3_bucket.dot-bucket.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
	  "Principal": "*",
      "Action": [ "s3:*" ],
      "Resource": [
        "${aws_s3_bucket.dot-bucket.arn}",
        "${aws_s3_bucket.dot-bucket.arn}/*"
      ]
    }
  ]
}
EOF
}

resource "aws_instance" "dot_server" {
  ami                    = var.base_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["sg-014e7d776fd09dab3"]
  key_name               = var.public_key          
  subnet_id              = "subnet-001e3a483390007de"
  iam_instance_profile = "dot-s3-access-role"

  tags = {"Name" = "dot_server"
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

output "dot_server_ip" {
  value = aws_instance.dot_server.public_ip
}
