
variable "credentials" {
        default = "../../gcpservice/terraform_account.json"
    }

variable "var_project" {
        default = "redislabs-sa-training-services"
    }

variable "region" {
        default = "us-central1"
}

 variable "zone" {
        default = "us-central1-a"
}   

 variable "vpc" {
        default = "kube"
}   

variable "gce_ssh_user" {
  default = "root"
}
variable "gce_ssh_pub_key_file" {
  default = "~/.ssh/id_rsa.pub"
}

variable "gce_public_subnet_cidr" {
  default = "10.10.0.0/24"
}

variable "gce_private_subnet_cidr" {
  default = "10.20.0.0/16"
}

variable "bastion-ip-address-count" {
  default = 1
}

variable "ubuntu" {
  default = "ubuntu-os-cloud/ubuntu-1804-lts"
}


variable "boot_disk_size" {
  default = 50
}

variable "bastion_machine_type" {
  default = "n1-standard-1"
}

variable "controller_machine_count" {
  default = 2
}
variable "controller_machine_type" {
  default = "n1-standard-4"
}


variable "worker_machine_count" {
  default = 2
}

variable "worker_machine_type" {
  default = "n1-standard-4"
}


variable "storage_machine_count" {
  default = 2
}
variable "storage_machine_type" {
  default = "n1-standard-4"
}

variable "storage_disk_size" {
  default = 100
}

variable "storage_disk_type" {
  default = "pd-standard"
}



