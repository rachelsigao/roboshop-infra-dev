resource "aws_instance" "bastion" {
  ami           = local.ami_id
  instance_type = "t3.micro"
  vpc_security_group_ids = [local.bastion_sg_id]
  subnet_id = local.public_subnet_id

  # EBS storage resize (need more for terraform)
  root_block_device {
    volume_size = 50
    volume_type = "gp3" # or "gp2", depending on your preference
  }
  user_data = file("bastion.sh")
  iam_instance_profile = "TerraformAdmin" # Gives bastion host, AWS permissions to run Terraform commands (like terraform apply from inside the bastion). create this IAM role in AWS first before running this folder
  tags = merge(
    local.common_tags,
    {
        Name = "${var.project}-${var.environment}-bastion"
    }
  )
}