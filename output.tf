output "public-ip_my_first_ec2" {
    value = module.ec2_instance.public_ip
}
output "my_first_ec2_status" {
  value = module.ec2_instance.instance_state
}
output "my_first_ec2_private_ip" {
  value = module.ec2_instance.private_ip
}
