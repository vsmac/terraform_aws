provider "aws" {
  region = var.region
}

data "aws_ami" "ami" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "http" "my_ip" {
  url = "http://whatismyip.akamai.com"
}

data "aws_availability_zones" "available" {
  state = "available"
}

# randomness
resource "random_id" "rand" {
  byte_length = 4
}

resource "random_shuffle" "subnets" {
  input        = var.public_subnet_ids
  result_count = 1
}

# iam
resource "aws_iam_role" "instance_deploy_role" {
  name               = "instance_deploy_role_${random_id.rand.hex}"
  assume_role_policy = templatefile("${path.module}/templates/instance_deploy_role.json", {})
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "instance_profile_${random_id.rand.hex}"
  role = "instance_deploy_role_${random_id.rand.hex}"
}

resource "aws_iam_role_policy" "instance_iam_role_policy" {
  name   = "instance_iam_role_policy_${random_id.rand.hex}"
  role   = aws_iam_role.instance_deploy_role.id
  policy = templatefile("${path.module}/templates/policy.json", {})
}

# security group
resource "aws_security_group" "instance_sg" {
  name        = "instance_sg_${random_id.rand.hex}"
  description = "Instance SecurityGroup ${random_id.rand.hex}"
  vpc_id      = var.vpc_id

  # Required for all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
    cidr_blocks = [var.vpc_cidr, "${data.http.my_ip.body}/32"]
  }
}

# private nic
resource "aws_network_interface" "instance_nic_private" {
  subnet_id       = element(random_shuffle.subnets.result, 0)
  security_groups = [aws_security_group.instance_sg.id]

  tags = {
    Name        = var.hostname
    environment = var.environment
    provisioner = "terraform"
  }
}

# instance
resource "aws_instance" "instance" {
  ami           = data.aws_ami.ami.image_id
  instance_type = var.instance_type
  key_name      = var.key_name

  lifecycle {
    ignore_changes = [ami]
  }

  root_block_device {
    volume_type           = var.root_block_device_type
    volume_size           = var.root_block_device_size_in_gb
    delete_on_termination = true
  }

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.instance_nic_private.id
  }

  user_data = templatefile("${path.module}/templates/cloud-config.yaml", {
    ansible_version        = var.ansible_version
    apt_update             = var.apt_update
    apt_upgrade            = var.apt_upgrade
    aws_environment        = var.environment
    aws_region             = var.region
    git_version            = var.git_version
    reboot_after_bootstrap = var.reboot_after_bootstrap
    s3_bucket              = var.s3_bucket
    secondary_block_device = var.secondary_block_device
  })

  iam_instance_profile = aws_iam_instance_profile.instance_profile.id

  tags = {
    Name        = var.hostname
    environment = var.environment
    provisioner = "terraform"
    region      = var.region
  }
}

resource "aws_ebs_volume" "secondary_volume" {
  count             = var.secondary_block_device ? 1 : 0
  size              = var.secondary_block_device_size_in_gb
  type              = var.secondary_block_device_type
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name        = var.hostname
    environment = var.environment
    provisioner = "terraform"
    region      = var.region
  }
}

resource "aws_volume_attachment" "ebs_att" {
  count       = var.secondary_block_device ? 1 : 0
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.secondary_volume[count.index].id
  instance_id = aws_instance.instance.id
}
