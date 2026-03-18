# Creating Target group for ALB to register the EC2 instances of catalogue. Without this, ALB cannotperform health check on the EC2 instances and route the traffic to the healthy instances.
resource "aws_lb_target_group" "catalogue" {
  name     = "${var.project}-${var.environment}-catalogue" #roboshop-dev-catalogue
  port     = 8080
  protocol = "HTTP"
  vpc_id   = local.vpc_id
  deregistration_delay = 120
  health_check {
    healthy_threshold = 2
    interval = 5
    matcher = "200-299"
    path = "/health"
    port = 8080
    timeout = 2
    unhealthy_threshold = 3
  }
}

# Creating the EC2 instance for catalogue.
resource "aws_instance" "catalogue" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.catalogue_sg_id]
  subnet_id = local.private_subnet_id
  #iam_instance_profile = "EC2RoleToFetchSSMParams"
  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-catalogue"
    }
  )
}

# Installing catalogue application on the EC2 instance.
resource "terraform_data" "catalogue" {
  triggers_replace = [
    aws_instance.catalogue.id
  ]
  
  provisioner "file" {
    source      = "catalogue.sh"
    destination = "/tmp/catalogue.sh"
  }

  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.catalogue.private_ip
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/catalogue.sh",
      "sudo sh /tmp/catalogue.sh catalogue ${var.environment}"
    ]
  }
}

# Stopping the EC2 instance to create AMI, as we cannot create AMI from running EC2 instance.
resource "aws_ec2_instance_state" "catalogue" {
  instance_id = aws_instance.catalogue.id
  state       = "stopped"
  depends_on = [terraform_data.catalogue]
}


resource "aws_ami_from_instance" "catalogue" {
  name               = "${var.project}-${var.environment}-catalogue"
  source_instance_id = aws_instance.catalogue.id
  depends_on = [aws_ec2_instance_state.catalogue]
  tags = merge(
    local.common_tags,
    {
      Name = "${var.project}-${var.environment}-catalogue"
    }
  )
}
# Terminate the EC2 instance after creating the AMI, as we don't need it. We will use the AMI to create the EC2 instances in the Auto Scaling group.
resource "terraform_data" "catalogue_delete" {
  triggers_replace = [
    aws_instance.catalogue.id
  ]
  
  # make sure you have aws configure in your laptop
  provisioner "local-exec" {
    command = "aws ec2 terminate-instances --instance-ids ${aws_instance.catalogue.id}"
  }

  depends_on = [aws_ami_from_instance.catalogue]
}

# Terminate the EC2 instance after creating the AMI, as we don't need it. We will use the AMI to create the EC2 instances in the Auto Scaling group.
resource "aws_launch_template" "catalogue" {
  name = "${var.project}-${var.environment}-catalogue"

  image_id = aws_ami_from_instance.catalogue.id
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.catalogue_sg_id]
  update_default_version = true # each time you update, new version will become default
  tag_specifications {
    resource_type = "instance"
    # EC2 tags created by ASG
    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-catalogue"
      }
    )
  }

  # volume tags created by ASG
  tag_specifications {
    resource_type = "volume"

    tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-catalogue"
      }
    )
  }

  # launch template tags
  tags = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-catalogue"
      }
  )

}

# Creating the Auto Scaling group for catalogue to automatically scale the EC2 instances based on the demand. 
resource "aws_autoscaling_group" "catalogue" {
  name                 = "${var.project}-${var.environment}-catalogue"
  desired_capacity   = 1
  max_size           = 10
  min_size           = 1
  target_group_arns = [aws_lb_target_group.catalogue.arn]
  vpc_zone_identifier  = local.private_subnet_ids
  health_check_grace_period = 90
  health_check_type         = "ELB"

  launch_template {
    id      = aws_launch_template.catalogue.id
    version = aws_launch_template.catalogue.latest_version
  }

  dynamic "tag" {
    for_each = merge(
      local.common_tags,
      {
        Name = "${var.project}-${var.environment}-catalogue"
      }
    )
    content{
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
    
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = ["launch_template"]
  }

  timeouts{
    delete = "15m"
  }
}

# Creating the Auto Scaling policy for catalogue to automatically scale the EC2 instances based on the CPU utilization.
resource "aws_autoscaling_policy" "catalogue" {
  name                   = "${var.project}-${var.environment}-catalogue"
  autoscaling_group_name = aws_autoscaling_group.catalogue.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}

# Creating the ALB listener rule to route the traffic to the target group based on the host header. This will allow us to access the catalogue application using the subdomain name instead of the ALB DNS name.
resource "aws_lb_listener_rule" "catalogue" {
  listener_arn = local.backend_alb_listener_arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.catalogue.arn
  }

  condition {
    host_header {
      values = ["catalogue.backend-${var.environment}.${var.zone_name}"]
    }
  }
}