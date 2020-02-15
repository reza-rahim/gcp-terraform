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

variable "os" {
  default = "ubuntu"
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

variable "gce_ssh_private_key_file" {
  default = "~/.ssh/id_rsa"
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
  default = "k8-image-1-5"
  #default = "ubuntu-os-cloud/ubuntu-1804-lts"
}

variable "boot_disk_size" {
  default = 50
}

variable "bastion_machine_type" {
  default = "n1-standard-1"
}

variable "kube_master_machine_count" {
  default = 3
}

variable "kube_master_machine_type" {
  default = "n1-standard-4"
}


variable "kube_ingress_machine_count" {
  default = 2
}

variable "kube_ingress_machine_type" {
  default = "n1-standard-4"
}

variable "kube_worker_machine_count" {
  default = 3
}

variable "kube_worker_machine_type" {
  default = "n1-standard-4"
}

variable "kube_storage_machine_count" {
  default = 3
}

variable "kube_storage_machine_type" {
  default = "n1-standard-4"
}

variable "kube_storage_disk_size" {
  default = 100
}

variable "kube_storage_disk_type" {
  default = "pd-standard"
}

