terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# -------------------------------------------------------
# DATA SOURCES
# -------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "defaultForAz"
    values = ["true"]
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# -------------------------------------------------------
# SECURITY GROUPS
# -------------------------------------------------------

resource "aws_security_group" "alb_sg" {
  name        = "phonebook-alb-sg"
  description = "Allow HTTP from anywhere to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "phonebook-alb-sg"
  }
}

resource "aws_security_group" "ec2_sg" {
  name        = "phonebook-ec2-sg"
  description = "Allow HTTP only from ALB security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "phonebook-ec2-sg"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "phonebook-rds-sg"
  description = "Allow MySQL from EC2 security group"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "phonebook-rds-sg"
  }
}

# -------------------------------------------------------
# RDS INSTANCE
# -------------------------------------------------------

resource "aws_db_instance" "phonebook_db" {
  identifier             = "phonebook-db"
  engine                 = "mysql"
  engine_version         = "8.0.19"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "phonebook"
  username               = "admin"
  password               = "Oliver_1"
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  tags = {
    Name = "phonebook-rds"
  }
}

# -------------------------------------------------------
# APPLICATION LOAD BALANCER
# -------------------------------------------------------

resource "aws_lb" "phonebook_alb" {
  name               = "phonebook-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids

  tags = {
    Name = "phonebook-alb"
  }
}

resource "aws_lb_target_group" "phonebook_tg" {
  name     = "phonebook-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "phonebook-tg"
  }
}

resource "aws_lb_listener" "phonebook_listener" {
  load_balancer_arn = aws_lb.phonebook_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.phonebook_tg.arn
  }
}

# -------------------------------------------------------
# LAUNCH TEMPLATE
# -------------------------------------------------------

resource "aws_launch_template" "phonebook_lt" {
  name          = "phonebook-launch-template"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  network_interfaces {
    security_groups             = [aws_security_group.ec2_sg.id]
    associate_public_ip_address = true
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y python3 python3-pip git
    pip3 install flask flask-mysql

    # Set RDS endpoint as environment variable
    export MYSQL_DATABASE_HOST="${aws_db_instance.phonebook_db.address}"

    # Clone the application from GitHub
    # Replace the URL below with your actual GitHub repo URL
    cd /home/ec2-user
    git clone https://github.com/YOUR_GITHUB_USERNAME/YOUR_REPO_NAME.git app
    cd app

    # Persist the env variable and run the app
    echo "export MYSQL_DATABASE_HOST=${aws_db_instance.phonebook_db.address}" >> /etc/profile
    MYSQL_DATABASE_HOST=${aws_db_instance.phonebook_db.address} python3 phonebook-app.py
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Web Server of Phonebook App"
    }
  }
}

# -------------------------------------------------------
# AUTO SCALING GROUP
# -------------------------------------------------------

resource "aws_autoscaling_group" "phonebook_asg" {
  name                      = "phonebook-asg"
  desired_capacity          = 2
  min_size                  = 1
  max_size                  = 3
  vpc_zone_identifier       = data.aws_subnets.default.ids
  target_group_arns         = [aws_lb_target_group.phonebook_tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.phonebook_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "Web Server of Phonebook App"
    propagate_at_launch = true
  }
}

# -------------------------------------------------------
# OUTPUTS
# -------------------------------------------------------

output "phonebook_app_url" {
  value       = "http://${aws_lb.phonebook_alb.dns_name}"
  description = "Phonebook Application URL"
}

output "rds_endpoint" {
  value       = aws_db_instance.phonebook_db.address
  description = "RDS MySQL Endpoint"
}
