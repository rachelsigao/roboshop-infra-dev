# # To get the VPC_id 
# output "vpc_ids" {
#    value = module.vpc.vpc_id 
# }

# To get the public subnet ids of the VPC 
output "vpc_ids" {
    value = module.vpc.public_subnet_ids
}

# # To get the availability zones information of the VPC
# output "azs_info" {
#     value = module.vpc.azs_info
# }