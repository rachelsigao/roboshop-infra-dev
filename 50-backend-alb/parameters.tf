# Storing ALB listener ARN in SSM parameter store to be used in the catalogue module to create the listener rule.
resource "aws_ssm_parameter" "backend_alb_listener_arn" {
  name  = "/${var.project}/${var.environment}/backend_alb_listener_arn"
  type  = "String"
  value = aws_lb_listener.backend_alb.arn
}