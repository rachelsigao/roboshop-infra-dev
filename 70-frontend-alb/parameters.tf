# Storing ALB listener ARN in SSM parameter store to be used in the frontend module to create the listener rule.
resource "aws_ssm_parameter" "frontend_alb_listener_arn" {
  name  = "/${var.project}/${var.environment}/frontend_alb_listener_arn"
  type  = "String"
  value = aws_lb_listener.frontend_alb.arn
}