output "bastion_ip" {
  description = "Public IP of bastion host"
  value       = aws_instance.bastion.public_ip
}

output "source_subnet" {
  value = module.network.subnet_ids["source"]
}

output "target_subnet" {
  value = module.network.subnet_ids["target"]
}
