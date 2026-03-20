module "frontend_alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "9.16.0"
  internal = false # ALB can be accessed from the internet.
  name    = "${var.project}-${var.environment}-frontend-alb" #roboshop-dev-backend-alb
  vpc_id  = local.vpc_id
  subnets = local.public_subnet_ids
  create_security_group = false
  security_groups = [local.frontend_alb_sg_id]
  enable_deletion_protection = false
  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-frontend-alb"
    }
  )
}

# Frontend Alb Listener configuration
resource "aws_lb_listener" "frontend_alb" {
  load_balancer_arn = module.frontend_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"
  certificate_arn   = local.acm_certificate_arn 
  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = "<h1>Hello, I am from frontend ALB using HTTPS</h1>"
      status_code  = "200"
    }
  }
}

# Creating Route53 Record for frontend ALB to avoid long DNS name of ALB and easily access the frontend using subdomain name.
resource "aws_route53_record" "frontend_alb" {
  zone_id = var.zone_id
  name    = "${var.environment}.${var.zone_name}" #dev.rachelsigao.online
  type    = "A"

  alias {
    name                   = module.frontend_alb.dns_name
    zone_id                = module.frontend_alb.zone_id # This is the ZONE ID of ALB
    evaluate_target_health = true
  }
}

