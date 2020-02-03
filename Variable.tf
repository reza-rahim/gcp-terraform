
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
  default = "10.10.0.0/16"
}

variable "gce_private_subnet_cidr" {
  default = "10.20.0.0/16"
}

variable "bastion-ip-address-count" {
  default = 2
}

