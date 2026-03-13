locals{
    ami_id = data.aws_ami.joindevops.id
    bastion_sg_id = data.aws_ssm_parameter.bastion_sg_id.value
    public_subnet_id = split ("," , data.aws_ssm_parameter.public_subnet_ids.value)[0] 
    # split function is used to convert the comma-separated string of subnet ids back into a list, and [0] is used to get the first subnet id from the list, which will be used for the bastion host.

    common_tags = {
        Project = var.project
        Environment = var.environment
        Terraform = "true"
    }
}