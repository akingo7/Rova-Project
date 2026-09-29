resource "aws_security_group" "alb" {
  name        = "rova-alb-sg"
  description = "Allow inbound HTTP traffic to ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["[IP_ADDRESS]"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["[IP_ADDRESS]"]
  }

  tags = var.tags
}

resource "aws_security_group" "app" {
  name        = "rova-app-sg"
  description = "Allow inbound HTTP traffic from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["[IP_ADDRESS]"]
  }

  tags = var.tags
}
