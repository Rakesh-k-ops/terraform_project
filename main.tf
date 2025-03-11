module "ec2_instance" {
  source = "./modules/ec2_instance"
  aws_region = var.aws_region
  ami_id = var.ami_id
  instance_type = var.instance_type
}
# Security Group
resource "aws_security_group" "app_sg" {
  name        = "app_security_group"
  description = "Allow HTTP & SSH"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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

# Launch Template
resource "aws_launch_template" "app_template" {
  name_prefix   = "app-template"
  image_id      = var.ami_id  # Change to your preferred AMI
  instance_type = var.instance_type

user_data = base64encode(<<-EOF
#!/bin/bash
apt update -y
apt install -y apache2
systemctl enable apache2
systemctl start apache2

# Create a sample index.html
echo "<h1>Welcome to My Web Server</h1>" > /var/www/html/index.html
EOF
) 
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.app_sg.id]
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "Terraform-ASG-Instance"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "app_asg" {
  desired_capacity     = 2
  min_size            = 2
  max_size            = 3
  vpc_zone_identifier = [ var.subnet_1_id, var.subnet_2_id]  # Change with your Subnet IDs

  launch_template {
    id      = aws_launch_template.app_template.id
    version = aws_launch_template.app_template.latest_version  
  }
}

# Load Balancer
resource "aws_lb" "app_lb" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets           = ["subnet-0739686a07685b631", "subnet-0472fa04e525a0a69"]  # Change accordingly
}

# Target Group
resource "aws_lb_target_group" "app_tg" {
  name     = "app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id  # Change to your VPC ID
}

# ALB Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# Attach ASG to ALB
resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = aws_autoscaling_group.app_asg.id
  lb_target_group_arn    = aws_lb_target_group.app_tg.arn
}
