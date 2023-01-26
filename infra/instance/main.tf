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
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "dot-public-subnet"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public Route Table"
  }
}

resource "aws_route_table_association" "public_1_rt_a" {
  subnet_id      = aws_subnet.dot-public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "ssh from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "TCP"
    cidr_blocks      = [aws_vpc.vpc.cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.dot_server.id
  allocation_id = aws_eip.dot-eip.id
}

resource "aws_instance" "dot_server" {
  ami                    = var.base_ami_id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["sg-014e7d776fd09dab3"]
  key_name               = var.public_key          
  subnet_id              = "subnet-001e3a483390007de"

  tags = {"Name" = "dot_server"
  }
}

resource "aws_eip" "dot-eip" {
  vpc = true
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