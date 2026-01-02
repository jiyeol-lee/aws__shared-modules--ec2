# =============================================================================
# Required Variables
# =============================================================================

variable "name" {
  description = "Name of the EC2 instance and related resources"
  type        = string

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 200
    error_message = "name must be between 1 and 200 characters to allow for resource suffixes."
  }
}

variable "vpc_id" {
  description = "VPC ID where the instance will be created"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID where the instance will be created"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
}

# =============================================================================
# Instance Configuration
# =============================================================================

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.nano"
}

variable "associate_public_ip_address" {
  description = "Associate a public IP address with the instance. Defaults to false for security - set to true if public access is required."
  type        = bool
  default     = false
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to the instance"
  type        = string
  default     = null
}

variable "enable_monitoring" {
  description = "Enable detailed CloudWatch monitoring (1-minute granularity). Costs ~$2.10/month. Note: CPU alarms work with basic monitoring (5-min) too."
  type        = bool
  default     = false
}

variable "user_data" {
  description = <<-EOT
    User data script for instance initialization.

    IMPORTANT: Changes to user_data after initial instance creation will NOT trigger
    instance replacement due to lifecycle ignore_changes. This prevents accidental
    instance destruction but means user_data updates require manual action.

    To apply user_data changes to an existing instance:
    - Option 1: terraform taint module.<name>.aws_instance.main
    - Option 2: Manually terminate the instance and run terraform apply
  EOT
  type        = string
  default     = null
}

# =============================================================================
# SSH Key Pair
# =============================================================================

variable "ssh_public_key" {
  description = "SSH public key to create key pair (if create_key_pair is true)"
  type        = string
  default     = null
  sensitive   = true
}

variable "create_key_pair" {
  description = "Whether to create a new key pair. If true, ssh_public_key must be provided."
  type        = bool
  default     = false
}

variable "key_name" {
  description = "Existing key pair name (if not creating new one)"
  type        = string
  default     = null
}

# =============================================================================
# Security Group Configuration
# =============================================================================

variable "security_group_description" {
  description = "Description for the security group"
  type        = string
  default     = "Security group for EC2 instance"
}

variable "ingress_rules" {
  description = "List of ingress rules for the security group. Default is empty - users must explicitly define rules."
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = []
}

variable "egress_rules" {
  description = "Outbound rules for security group (defaults to allow all outbound)"
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
    description = string
  }))
  default = [
    {
      description = "Allow all outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# =============================================================================
# Root Volume Settings
# =============================================================================

variable "root_volume_type" {
  description = "Type of root EBS volume (gp2, gp3, io1, io2, standard)"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "standard"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3, io1, io2, standard."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB. Minimum 8 GB for most AMIs."
  type        = number
  default     = 8

  validation {
    condition     = var.root_volume_size >= 8
    error_message = "root_volume_size must be at least 8 GB."
  }
}

variable "root_volume_encrypted" {
  description = "Encrypt the root volume"
  type        = bool
  default     = true
}

variable "root_volume_delete_on_termination" {
  description = "Delete root volume when instance is terminated"
  type        = bool
  default     = true
}

variable "root_volume_iops" {
  description = "IOPS for root volume (for io1/io2 or gp3)"
  type        = number
  default     = null
}

variable "root_volume_throughput" {
  description = "Throughput in MiB/s for root volume (for gp3)"
  type        = number
  default     = null
}

# =============================================================================
# Additional Volumes
# =============================================================================

variable "additional_volumes" {
  description = "Additional EBS volumes to attach"
  type = list(object({
    device_name           = string
    volume_type           = string
    volume_size           = number
    encrypted             = bool
    iops                  = optional(number)
    throughput            = optional(number)
    delete_on_termination = optional(bool, true)
  }))
  default = []

  validation {
    condition = alltrue([
      for vol in var.additional_volumes : contains(["gp2", "gp3", "io1", "io2", "st1", "sc1", "standard"], vol.volume_type)
    ])
    error_message = "additional_volumes volume_type must be one of: gp2, gp3, io1, io2, st1, sc1, standard."
  }
}

# =============================================================================
# IMDSv2 Settings
# =============================================================================

variable "imdsv2_required" {
  description = "Require IMDSv2 (instance metadata service version 2)"
  type        = bool
  default     = true
}

variable "metadata_hop_limit" {
  description = "Number of hops for IMDSv2"
  type        = number
  default     = 1

  validation {
    condition     = var.metadata_hop_limit >= 1 && var.metadata_hop_limit <= 64
    error_message = "metadata_hop_limit must be between 1 and 64."
  }
}

# =============================================================================
# CloudWatch Alarm Settings
# =============================================================================

variable "create_cpu_alarm" {
  description = "Create CloudWatch CPU utilization alarm. Works with both basic (5-min) and detailed (1-min) monitoring."
  type        = bool
  default     = false
}

variable "alarm_cpu_threshold" {
  description = "CPU utilization threshold percentage for the alarm (0-100)"
  type        = number
  default     = 80

  validation {
    condition     = var.alarm_cpu_threshold >= 0 && var.alarm_cpu_threshold <= 100
    error_message = "alarm_cpu_threshold must be between 0 and 100."
  }
}

variable "alarm_evaluation_periods" {
  description = "Number of periods to evaluate for alarm"
  type        = number
  default     = 2
}

variable "alarm_period" {
  description = "Period in seconds for each evaluation"
  type        = number
  default     = 300

  validation {
    condition     = var.alarm_period >= 60 && var.alarm_period % 60 == 0
    error_message = "alarm_period must be >= 60 seconds and a multiple of 60."
  }
}

variable "alarm_actions" {
  description = "Actions to take when alarm triggers"
  type        = list(string)
  default     = []
}

variable "insufficient_data_actions" {
  description = "Actions to take when alarm has insufficient data"
  type        = list(string)
  default     = []
}

variable "ok_actions" {
  description = "Actions to take when alarm returns to OK state"
  type        = list(string)
  default     = []
}

# =============================================================================
# Tags
# =============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy  = "Terraform"
    RootModule = "aws__shared-modules--ec2"
  }
}
