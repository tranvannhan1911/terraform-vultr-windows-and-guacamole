# Administrator
# a5*L9Y_m]dTTknUz

terraform {
  required_providers {
    vultr = {
      source  = "vultr/vultr"
      version = "2.12.1"
    }
    guacamole = {
      source = "techBeck03/guacamole"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
}

############ Vultr arguments ##############
variable "number_of_vm" {
  type    = number
  default = 2
}

variable "vultr_api_key" {
  type    = string
  default = "DGBLLMRTZIO6R2DTWDHODSPGKPVTIN5P63ZA"
}

variable "region" {
  type    = string
  default = "sgp"
}

variable "plan" {
  type    = string
  default = "vc2-1c-2gb"
}

variable "enable_auto_backup" {
  type    = string
  default = "disabled"
}

variable "snapshot_id" {
  type    = string
  default = "21d6c0cc-4d97-41eb-bd88-94a6da91e0b5"
}

variable "snapshot_password" {
  type    = string
  default = "a5*L9Y_m]dTTknUz"
}
############ Guacamole arguments ##############
variable "guacamole_url" {
  type    = string
  default = "https://45.32.99.175"
}

variable "guacamole_username" {
  type    = string
  default = "guacadmin"
}

variable "guacamole_password" {
  type    = string
  default = "guacadmin"
}

variable "guacamole_protocol" {
  type    = string
  default = "rdp"
}

############ Provider ##############
provider "vultr" {
  api_key = var.vultr_api_key
}

provider "guacamole" {
  url                      = var.guacamole_url
  username                 = var.guacamole_username
  password                 = var.guacamole_password
  disable_tls_verification = true
}

provider "random" {
}

############ Create VM Vultr ##############
resource "vultr_instance" "cloud_compute" {
  count       = var.number_of_vm
  region      = var.region
  plan        = var.plan
  backups     = var.enable_auto_backup
  enable_ipv6 = true
  snapshot_id = var.snapshot_id
  label       = "vm-${count.index}"
  hostname    = "vm-${count.index}"
}

############ Create Connection ##############
resource "guacamole_connection_rdp" "rdp" {
  count             = var.number_of_vm
  name              = "Window VM - ${count.index}"
  parent_identifier = "ROOT"
  parameters {
    hostname           = vultr_instance.cloud_compute.*.main_ip[count.index]
    username           = "Administrator"
    password           = var.snapshot_password
    domain             = "WORKGROUP"
    port               = 3389
    security_mode      = "any"
    ignore_cert        = true
  }
}


############ Random username and password ##############
resource "random_string" "username" {
  count   = var.number_of_vm
  length  = 10
  special = false
  upper   = false
}

resource "random_password" "password" {
  count            = var.number_of_vm
  length           = 16
  special          = true
  override_special = "!@#$%^&*()-_=+"
}

############ Create user ##############
resource "guacamole_user" "user" {
  count    = var.number_of_vm
  username = "${random_string.username[count.index].result}_${count.index}"
  password = random_password.password[count.index].result
  connections = [
    guacamole_connection_rdp.rdp[count.index].id
  ]
}

############## output ################
output "cloud_compute_ip_address" {
  value = vultr_instance.cloud_compute.*.main_ip
}

output "vm_connections" {
  value = guacamole_connection_rdp.rdp.*.id
}

output "username" {
  #   value = random_string.username.*.result
  sensitive = true
  value = {
    for i, v in random_string.username :
    format("user %d", i + 1) => {
      "username" : "${v.result}_${i}",
      "password" : random_password.password[i].result,
      "ip": vultr_instance.cloud_compute.*.main_ip[i]
    }
  }
}