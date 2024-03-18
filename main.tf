
# Security group for web

resource "aws_security_group" "web" {
  name        = "web"
  description = "ec2 security group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "example"
  }
}

# VPC, Internet Gateway, and Subnets
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_subnet" "public_subnets" {
  count                  = 3
  vpc_id                 = aws_vpc.my_vpc.id
  cidr_block             = "10.0.${count.index}.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnets" {
  count                  = 3
  vpc_id                 = aws_vpc.my_vpc.id
  cidr_block             = "10.0.${count.index + 3}.0/24"
}

# Network Gateway for private subnets
resource "aws_nat_gateway" "my_nat_gateway" {
  count       = 3
  allocation_id = aws_eip.my_eip[count.index].id
  subnet_id     = aws_subnet.public_subnets[count.index].id
}

resource "aws_eip" "my_eip" {
  count = 3
}

# Auto Scaling Group (ASG) and Launch Template
resource "aws_launch_template" "my_launch_template" {
  name_prefix   = "my-launch-template"
  image_id      = "ami-02d7fd1c2af6eead0" # Specify your AMI ID
  instance_type = "t2.micro" # Specify your instance type
  user_data = <<-EOF
    #!/bin/bash
    echo "WORDPRESS_DB_HOST=writer.yourdomain.com" >> /etc/environment
    # Add other necessary environment variables
    EOF
}

resource "aws_autoscaling_group" "my_asg" {
  launch_template {
    id = aws_launch_template.my_launch_template.id
  }
  vpc_zone_identifier = aws_subnet.private_subnets[*].id
  min_size            = 1
  max_size            = 99
}

# Application Load Balancer (ALB)
resource "aws_lb" "my_alb" {
  name               = "my-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public_subnets[1].id
}

# Route 53 DNS Records
resource "aws_route53_record" "wordpress_record" {
  zone_id = "Z088083418MWN57KO0N03" # Specify your hosted zone ID
  name    = "wordpress.kabysov.com"
  type    = "A"
  alias {
    name                   = aws_lb.my_alb.dns_name
    zone_id                = aws_lb.my_alb.zone_id
    evaluate_target_health = true
  }
}

# RDS Cluster
resource "aws_rds_cluster" "my_rds_cluster" {
  cluster_identifier          = "my-rds-cluster"
  engine                      = "aurora-mysql"
  engine_mode                 = "provisioned"
  database_name               = "my_database"
  master_username             = "admin"
  master_password             = "admin123"
  backup_retention_period     = 7
  preferred_backup_window     = "07:00-09:00"
  port                        = 3306

  db_subnet_group_name        = aws_db_subnet_group.my_db_subnet_group.name
  vpc_security_group_ids      = [aws_security_group.my_db_security_group.id]
}

# RDS Subnet Group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = aws_subnet.private_subnets[*].id
}

# RDS Security Group
resource "aws_security_group" "my_db_security_group" {
  name        = "my-db-security-group"
  description = "Security group for RDS"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Route 53 DNS Records for RDS Endpoints
resource "aws_route53_record" "writer_record" {
  zone_id = "Z088083418MWN57KO0N03" # Specify your hosted zone ID
  name    = "writer.kabysov.com"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_rds_cluster.my_rds_cluster.endpoint]

  # Replace "your_zone_id" with the actual Route 53 zone ID for your domain
}

resource "aws_route53_record" "reader1_record" {
  zone_id = "Z088083418MWN57KO0N03" # Specify your hosted zone ID
  name    = "reader1.kabysov.com"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_rds_cluster.my_rds_cluster.reader_endpoint]

  # Replace "your_zone_id" with the actual Route 53 zone ID for your domain
}

resource "aws_route53_record" "reader2_record" {
  zone_id = "Z088083418MWN57KO0N03" # Specify your hosted zone ID
  name    = "reader2.kabysov.com"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_rds_cluster.my_rds_cluster.reader_endpoint]

  # Replace "your_zone_id" with the actual Route 53 zone ID for your domain
}

resource "aws_route53_record" "reader3_record" {
  zone_id = "Z088083418MWN57KO0N03" # Specify your hosted zone ID
  name    = "reader3.kabysov.com"
  type    = "CNAME"
  ttl     = "300"
  records = [aws_rds_cluster.my_rds_cluster.reader_endpoint]

  # Replace "your_zone_id" with the actual Route 53 zone ID for your domain
}
