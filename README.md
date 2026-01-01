# AWS EC2 Module

Terraform module for creating an EC2 instance with configurable networking, storage, security, and monitoring.

## Key Features

- Configurable instance type (default: t4g.nano for cost optimization)
- Security group with customizable inbound/outbound rules using dynamic blocks
- EBS volume support with encryption (root + additional volumes)
- IAM instance profile support
- CloudWatch monitoring with optional CPU alarm
- User data injection for instance initialization
- IMDSv2 enforcement by default (enhanced security)
- Consistent tagging across all resources

## Security Notice

**Important**: This module defaults to an empty `ingress_rules` list. You must explicitly define security group rules for your use case. This is a security best practice to prevent accidentally exposing services to the internet.

**ARM Architecture**: The default instance type `t4g.nano` uses ARM (Graviton) processors. Ensure your AMI is ARM-compatible (e.g., Amazon Linux 2023 ARM64).

## Usage

### Basic Example

```hcl
module "ec2_instance" {
  source = "git@github.com:your-org/aws__shared-modules--aws-ec2.git"

  name      = "my-instance"
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  ami_id    = data.aws_ami.amazon_linux_2023.id

  # Security: You must explicitly define ingress rules
  ingress_rules = [
    {
      description = "SSH from my IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["YOUR_IP/32"]  # Replace with your IP
    }
  ]

  tags = {
    Project = "example"
  }
}
```

### With Custom Security Group Rules

```hcl
module "ec2_instance" {
  source = "git@github.com:your-org/aws__shared-modules--aws-ec2.git"

  name      = "my-instance"
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  ami_id    = data.aws_ami.amazon_linux_2023.id

  ingress_rules = [
    {
      description = "SSH from my IP"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["1.2.3.4/32"]
    },
    {
      description = "Custom app port"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}
```

### With Additional EBS Volume

```hcl
module "ec2_instance" {
  source = "git@github.com:your-org/aws__shared-modules--aws-ec2.git"

  name      = "my-instance"
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  ami_id    = data.aws_ami.amazon_linux_2023.id

  additional_volumes = [
    {
      device_name = "/dev/sdb"
      volume_type = "gp3"
      volume_size = 100
      encrypted   = true
    }
  ]
}
```

### With SSH Key Pair Creation

```hcl
module "ec2_instance" {
  source = "git@github.com:your-org/aws__shared-modules--aws-ec2.git"

  name      = "my-instance"
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  ami_id    = data.aws_ami.amazon_linux_2023.id

  create_key_pair = true
  ssh_public_key  = file("~/.ssh/id_rsa.pub")
}
```

### With User Data (Docker Installation)

```hcl
module "ec2_instance" {
  source = "git@github.com:your-org/aws__shared-modules--aws-ec2.git"

  name      = "docker-host"
  vpc_id    = var.vpc_id
  subnet_id = var.subnet_id
  ami_id    = data.aws_ami.amazon_linux_2023.id

  root_volume_size = 20

  user_data = <<-EOF
    #!/bin/bash
    dnf update -y
    dnf install -y docker
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ec2-user
  EOF
}
```

## Inputs

| Name                              | Description                                                                                                    | Type           | Default                                                                | Required |
| --------------------------------- | -------------------------------------------------------------------------------------------------------------- | -------------- | ---------------------------------------------------------------------- | :------: |
| name                              | Name of the EC2 instance and related resources                                                                 | `string`       | n/a                                                                    |   yes    |
| vpc_id                            | VPC ID where the instance will be created                                                                      | `string`       | n/a                                                                    |   yes    |
| subnet_id                         | Subnet ID where the instance will be created                                                                   | `string`       | n/a                                                                    |   yes    |
| ami_id                            | AMI ID for the EC2 instance                                                                                    | `string`       | n/a                                                                    |   yes    |
| instance_type                     | EC2 instance type                                                                                              | `string`       | `"t4g.nano"`                                                           |    no    |
| associate_public_ip_address       | Associate a public IP address with the instance                                                                | `bool`         | `true`                                                                 |    no    |
| ssh_public_key                    | SSH public key to create key pair (if create_key_pair is true)                                                 | `string`       | `null`                                                                 |    no    |
| create_key_pair                   | Create a new key pair using ssh_public_key                                                                     | `bool`         | `false`                                                                |    no    |
| key_name                          | Existing key pair name (if not creating new one)                                                               | `string`       | `null`                                                                 |    no    |
| security_group_description        | Description for the security group                                                                             | `string`       | `"Security group for EC2 instance"`                                    |    no    |
| ingress_rules                     | List of ingress rules for the security group. Default is empty - users must explicitly define rules.           | `list(object)` | `[]`                                                                   |    no    |
| egress_rules                      | Outbound rules for security group                                                                              | `list(object)` | Allow all                                                              |    no    |
| iam_instance_profile              | IAM instance profile name to attach                                                                            | `string`       | `null`                                                                 |    no    |
| enable_monitoring                 | Enable detailed CloudWatch monitoring. Costs ~$2.10/month. Set to true only if 1-minute granularity is needed. | `bool`         | `false`                                                                |    no    |
| user_data                         | User data script for instance initialization                                                                   | `string`       | `null`                                                                 |    no    |
| tags                              | Tags to apply to all resources                                                                                 | `map(string)`  | `{"ManagedBy": "Terraform", "RootModule": "aws__shared-modules--ec2"}` |    no    |
| root_volume_type                  | Root volume type (gp2, gp3, io1, io2, standard)                                                                | `string`       | `"gp3"`                                                                |    no    |
| root_volume_size                  | Root volume size in GB                                                                                         | `number`       | `8`                                                                    |    no    |
| root_volume_encrypted             | Encrypt the root volume                                                                                        | `bool`         | `true`                                                                 |    no    |
| root_volume_delete_on_termination | Delete root volume when instance is terminated                                                                 | `bool`         | `true`                                                                 |    no    |
| root_volume_iops                  | IOPS for root volume (for io1/io2 or gp3)                                                                      | `number`       | `null`                                                                 |    no    |
| root_volume_throughput            | Throughput in MiB/s for root volume (for gp3)                                                                  | `number`       | `null`                                                                 |    no    |
| additional_volumes                | Additional EBS volumes to attach                                                                               | `list(object)` | `[]`                                                                   |    no    |
| imdsv2_required                   | Require IMDSv2 (instance metadata service version 2)                                                           | `bool`         | `true`                                                                 |    no    |
| metadata_hop_limit                | Number of hops for IMDSv2                                                                                      | `number`       | `1`                                                                    |    no    |
| create_cpu_alarm                  | Create CloudWatch alarm for high CPU usage                                                                     | `bool`         | `true`                                                                 |    no    |
| alarm_cpu_threshold               | CPU threshold percentage for alarm                                                                             | `number`       | `80`                                                                   |    no    |
| alarm_evaluation_periods          | Number of periods to evaluate for alarm                                                                        | `number`       | `2`                                                                    |    no    |
| alarm_period                      | Period in seconds for each evaluation                                                                          | `number`       | `300`                                                                  |    no    |
| alarm_actions                     | Actions to take when alarm triggers                                                                            | `list(string)` | `[]`                                                                   |    no    |
| insufficient_data_actions         | Actions to take when alarm has insufficient data                                                               | `list(string)` | `[]`                                                                   |    no    |
| ok_actions                        | Actions to take when alarm returns to OK state                                                                 | `list(string)` | `[]`                                                                   |    no    |

## Outputs

| Name                  | Description                                    |
| --------------------- | ---------------------------------------------- |
| instance_id           | ID of the EC2 instance                         |
| instance_arn          | ARN of the EC2 instance                        |
| instance_public_ip    | Public IP address of the instance              |
| instance_private_ip   | Private IP address of the instance             |
| instance_public_dns   | Public DNS name of the instance                |
| instance_private_dns  | Private DNS name of the instance               |
| availability_zone     | Availability zone of the instance              |
| security_group_id     | ID of the security group                       |
| security_group_arn    | ARN of the security group                      |
| key_pair_name         | Name of the SSH key pair (created or existing) |
| root_volume_id        | ID of the root volume                          |
| additional_volume_ids | IDs of additional EBS volumes                  |
| cpu_alarm_id          | ID of the CPU alarm (if created)               |

## Security Considerations

### Default Security Features

1. **IMDSv2 Enforcement**: Prevents SSRF attacks targeting instance metadata
2. **Encrypted Volumes**: Root volume encrypted by default
3. **Security Groups**: Empty by default - you must explicitly define ingress rules (security best practice)
4. **Key-based Auth**: SSH key pair authentication only

### ARM Architecture Note

The default instance type `t4g.nano` uses AWS Graviton (ARM) processors. When selecting an AMI:

- Use ARM64/aarch64 AMIs (e.g., `al2023-ami-*-arm64`)
- x86_64 AMIs will not work with t4g instances
- For x86 instances, change to `t3.nano` or similar

### Best Practices

- Restrict SSH CIDR to specific IP addresses
- Use IAM roles instead of access keys on instances
- Enable VPC Flow Logs for network monitoring
- Regularly rotate SSH keys
- Keep AMIs patched and updated
