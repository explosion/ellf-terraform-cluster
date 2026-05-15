provider "aws" {
  region = var.aws_region
}

provider "random" {
}

# -------------
# Network
# -------------

resource "aws_vpc" "cluster" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.network_name
  }
}

resource "aws_internet_gateway" "cluster" {
  vpc_id = aws_vpc.cluster.id

  tags = {
    Name = "${var.network_name}-igw"
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.cluster.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = false

  tags = {
    Name                              = "${var.network_name}-private-${count.index}"
    "kubernetes.io/role/internal-elb" = "1"
  }
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id            = aws_vpc.cluster.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, count.index + 4)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name                     = "${var.network_name}-public-${count.index}"
    "kubernetes.io/role/elb" = "1"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.network_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "cluster" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.network_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.cluster]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.cluster.id
  }

  tags = {
    Name = "${var.network_name}-private-rt"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cluster.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cluster.id
  }

  tags = {
    Name = "${var.network_name}-public-rt"
  }
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --------------------
# Container registry
# --------------------

resource "aws_ecr_repository" "default" {
  name                 = var.repository_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# --------------
# S3 bucket
# --------------

resource "aws_s3_bucket" "data" {
  bucket        = "${var.network_name}-data"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ---------
# Database
# ---------

module "database" {
  source   = "../../modules/aws/database/"
  prefix   = "cluster"
  vpc_id   = aws_vpc.cluster.id
  vpc_cidr = var.vpc_cidr
  subnet_ids = aws_subnet.private[*].id
  user     = var.database_user
  name     = var.database_name
  depends_on = [aws_vpc.cluster]
}

# ---------
# Cluster
# ---------

module "cluster" {
  source     = "../../modules/aws/eks"
  aws_region = var.aws_region
  prefix     = "cluster"
  vpc_id     = aws_vpc.cluster.id

  private_subnet_ids = aws_subnet.private[*].id

  system_node_pool_instance_type = var.system_node_pool_instance_type
  system_node_pool_size          = var.system_node_pool_size
  worker_types                   = var.worker_types
  enable_ssh                     = var.enable_ssh

  domain = var.domain

  database_password = module.database.database_password
}
