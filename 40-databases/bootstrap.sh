#!/bin/bash

component=$1 
dnf install ansible -y
# pull the ansible playbook from the github repository and execute it. This will install the database on the EC2 instance. 
ansible-pull -U https://github.com/rachelsigao/ansible-roboshop-roles-tf.git -e component=$1 -e env=$2 main.yaml