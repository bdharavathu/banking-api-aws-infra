resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Public ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "app" {
  name        = "${var.name}-app"
  description = "ECS tasks, reachable only from the ALB"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-app" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db"
  description = "RDS, reachable only from the ECS tasks"
  vpc_id      = var.vpc_id
  tags        = { Name = "${var.name}-db" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTPS from clients"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:Port 80 only issues a 301 redirect to HTTPS
  for_each          = toset(var.allowed_ingress_cidrs)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from clients, redirected to HTTPS"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "ALB to app tasks"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.app.id
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "App port from ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "app_to_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "App to PostgreSQL"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.db.id
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  count             = var.enable_interface_endpoints ? 0 : 1
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to AWS APIs through NAT"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_to_endpoints" {
  count                        = var.enable_interface_endpoints ? 1 : 0
  security_group_id            = aws_security_group.app.id
  description                  = "HTTPS to VPC interface endpoints"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = var.endpoints_security_group_id
}

resource "aws_vpc_security_group_egress_rule" "app_to_s3" {
  count             = var.enable_interface_endpoints ? 1 : 0
  security_group_id = aws_security_group.app.id
  description       = "HTTPS to S3 gateway endpoint (image layers)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  prefix_list_id    = var.s3_prefix_list_id
}

moved {
  from = aws_vpc_security_group_egress_rule.app_https
  to   = aws_vpc_security_group_egress_rule.app_https[0]
}

resource "aws_vpc_security_group_ingress_rule" "db_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from app tasks"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.app.id
}
