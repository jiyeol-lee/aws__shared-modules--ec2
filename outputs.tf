# =============================================================================
# Instance Outputs
# =============================================================================

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.main.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.main.arn
}

output "instance_public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.main.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.main.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the instance"
  value       = aws_instance.main.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the instance"
  value       = aws_instance.main.private_dns
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.main.availability_zone
}

# =============================================================================
# Security Group Outputs
# =============================================================================

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.main.id
}

output "security_group_arn" {
  description = "ARN of the security group"
  value       = aws_security_group.main.arn
}

# =============================================================================
# Key Pair Outputs
# =============================================================================

output "key_pair_name" {
  description = "Name of the SSH key pair (created or existing)"
  value       = var.create_key_pair ? aws_key_pair.main[0].key_name : var.key_name
}

# =============================================================================
# Volume Outputs
# =============================================================================

output "root_volume_id" {
  description = "ID of the root volume"
  value       = aws_instance.main.root_block_device[0].volume_id
}

output "additional_volume_ids" {
  description = "IDs of additional EBS volumes"
  value = [
    for vol in aws_instance.main.ebs_block_device :
    vol.volume_id
  ]
}

# =============================================================================
# CloudWatch Alarm Outputs
# =============================================================================

output "cpu_alarm_id" {
  description = "ID of the CPU alarm (if created)"
  value       = var.create_cpu_alarm ? aws_cloudwatch_metric_alarm.cpu[0].id : null
}
