# terraform variables
variable "environment" {
  type = string

  validation {
    condition     = can(regex("^(demo|dev|qa|prod)$", var.environment))
    error_message = "The environment can be either demo/dev/qa/prod."
  }
}

variable "hostname" {
  type    = string
  default = ""
}

variable "instance_type" {
  type    = string
  default = "t2.small"
}

variable "key_name" {
  type = string
}

variable "region" {
  type = string

  validation {
    condition     = can(regex("^(us|af|ap|ca|eu|me|sa)\\-(east|west|south|northeast|southeast|central|north)\\-(1|2|3)$", var.region))
    error_message = "The region must be a proper AWS region."
  }
}

variable "root_block_device_type" {
  type    = string
  default = "standard"
}

variable "root_block_device_size_in_gb" {
  type    = number
  default = 8
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "secondary_block_device" {
  type    = bool
  default = false
}

variable "secondary_block_device_type" {
  type    = string
  default = "standard"
}

variable "secondary_block_device_size_in_gb" {
  type    = number
  default = 10
}

variable "public_subnet_ids" {
  type = list(string)
}

# cloud-init pass-thru variables
variable "apt_update" {
  type        = bool
  default     = true
  description = "Performs an apt update when set to true"
}

variable "apt_upgrade" {
  type        = bool
  default     = true
  description = "Performs an apt upgrade when set to true"
}

variable "reboot_after_bootstrap" {
  type        = bool
  default     = true
  description = "reboot after cloud-config initialization"
}

# ansible pass-thru variables
variable "ansible_version" {
  type    = string
  default = "2.9.15"
}

variable "git_version" {
  type    = string
  default = "master"
}

variable "s3_bucket" {
  type    = string
  default = "test"
}
