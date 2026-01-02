terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Security Group
resource "aws_security_group" "main" {
  name_prefix = "${var.name}-sg-"
  description = var.security_group_description
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
      description = ingress.value.description
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
      description = egress.value.description
    }
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# SSH Key Pair (optional - create if provided)
resource "aws_key_pair" "main" {
  count = var.create_key_pair ? 1 : 0

  key_name_prefix = "${var.name}-"
  public_key      = var.ssh_public_key

  lifecycle {
    precondition {
      condition     = var.ssh_public_key != null && var.ssh_public_key != ""
      error_message = "ssh_public_key must be provided when create_key_pair is true."
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-key"
  })
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  key_name                    = var.create_key_pair ? aws_key_pair.main[0].key_name : var.key_name
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.main.id]
  associate_public_ip_address = var.associate_public_ip_address
  monitoring                  = var.enable_monitoring
  iam_instance_profile        = var.iam_instance_profile
  user_data                   = var.user_data

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = var.root_volume_encrypted
    delete_on_termination = var.root_volume_delete_on_termination
    iops                  = var.root_volume_iops
    throughput            = var.root_volume_throughput
  }

  # Attach additional EBS volumes
  dynamic "ebs_block_device" {
    for_each = var.additional_volumes

    content {
      device_name           = ebs_block_device.value.device_name
      volume_type           = ebs_block_device.value.volume_type
      volume_size           = ebs_block_device.value.volume_size
      encrypted             = ebs_block_device.value.encrypted
      delete_on_termination = ebs_block_device.value.delete_on_termination
      iops                  = ebs_block_device.value.iops
      throughput            = ebs_block_device.value.throughput
    }
  }

  metadata_options {
    http_tokens                 = var.imdsv2_required ? "required" : "optional"
    http_endpoint               = "enabled"
    http_put_response_hop_limit = var.metadata_hop_limit
  }

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )

  lifecycle {
    create_before_destroy = false
    # IMPORTANT: user_data changes are intentionally ignored to prevent accidental
    # instance replacement. This is a safety measure but causes configuration drift.
    # Users must manually taint or replace the instance to apply user_data changes.
    # Note: Terraform's ignore_changes cannot be made variable (must be static).
    ignore_changes = [
      user_data
    ]
  }
}

# CloudWatch CPU Alarm (optional)
# Metric resolution depends on EC2 monitoring level:
# - Basic monitoring (default, free): 5-minute resolution, alarm_period must be >= 300s
# - Detailed monitoring ($2.10/month): 1-minute resolution, alarm_period can be 60s+
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.create_cpu_alarm ? 1 : 0

  alarm_name          = "${var.name}-cpu-high"
  alarm_description   = "Monitors CPU utilization for ${var.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.alarm_period
  statistic           = "Average"
  threshold           = var.alarm_cpu_threshold

  dimensions = {
    InstanceId = aws_instance.main.id
  }

  alarm_actions             = var.alarm_actions
  insufficient_data_actions = var.insufficient_data_actions
  ok_actions                = var.ok_actions

  tags = merge(
    var.tags,
    {
      Name = "${var.name}-cpu-alarm"
    }
  )

  lifecycle {
    precondition {
      condition     = var.enable_monitoring || var.alarm_period >= 300
      error_message = "alarm_period < 300s requires enable_monitoring = true. Basic monitoring (default) provides 5-minute metrics; detailed monitoring provides 1-minute metrics."
    }
  }
}
