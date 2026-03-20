module "user" {
    source = "../../terraform-roboshop-module"
    component = "user"
    rule_priority = 20
}