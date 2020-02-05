provider "google" {
  credentials = file(var.credentials)
  project     = var.var_project
  region      = var.region
  zone        = var.zone
}

resource "google_compute_network" "vpc" {
  name                    = var.vpc
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"

}

resource "google_compute_subnetwork" "public-subnet" {
  name          = "public-subnet"
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.gce_public_subnet_cidr
}

resource "google_compute_subnetwork" "private-subnet" {
  name          = "private-subnet"
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.gce_private_subnet_cidr
}

resource "google_compute_router" "router" {
  name    = "router"
  region  = google_compute_subnetwork.private-subnet.region
  network = google_compute_network.vpc.self_link
  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "simple-nat" {
  name                               = "nat-1"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_compute_firewall" "private-firewall" {
  name    = "private-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = [var.gce_public_subnet_cidr, var.gce_private_subnet_cidr]
}

resource "google_compute_firewall" "public-firewall" {
  name    = "public-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_address" "bastion-ip-address" {
  #count = var.bastion-ip-address-count
  #name  = "bastion-ip-address-${count.index}"
  name  = "bastion-ip-address"
}

resource "google_compute_instance" "bastion" {
  #count        = var.bastion-ip-address-count
  #name         = "bastion-${count.index}"
  name         = "bastion"
  machine_type = var.bastion_machine_type

  #can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "bastion"]

  boot_disk {
    initialize_params {
      image = var.ubuntu
      size  = var.boot_disk_size
    }
  }


  network_interface {
    subnetwork = google_compute_subnetwork.public-subnet.name

    #network_ip = "10.10.0.${count.index+2}"

    access_config {
      nat_ip  = google_compute_address.bastion-ip-address.address
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "apt-get install -y python"

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }


  
}

resource "google_compute_instance" "kube-master" {
  count        = var.kube_master_machine_count
  name         = "kube-master-${count.index}"
  machine_type = var.kube_master_machine_type

  #can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-master"]

  boot_disk {
    initialize_params {
      image = var.ubuntu
      size  = var.boot_disk_size
    }
  }


  network_interface {
    subnetwork = google_compute_subnetwork.private-subnet.name
    #network_ip = "10.10.0.${count.index+4}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  metadata_startup_script = "apt-get install -y python"
}

resource "google_compute_instance" "kube-worker" {
  count        = var.kube_worker_machine_count
  name         = "kube-worker-${count.index}"
  machine_type = var.kube_worker_machine_type

  #can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-worker"]

  boot_disk {
    initialize_params {
      image = var.ubuntu
      size  = var.boot_disk_size
    }
  }


  network_interface {
    subnetwork = google_compute_subnetwork.private-subnet.name
    #network_ip = "10.20.0.${count.index+3}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  metadata_startup_script = "apt-get install -y python"
}

resource "google_compute_disk" "storage-disk-b-" {
  count = var.kube_storage_machine_count
  name  = "storage-disk-b-${count.index}-data"
  type  = var.kube_storage_disk_type
  zone  = var.zone
  size  = var.kube_storage_disk_size
}

resource "google_compute_disk" "storage-disk-c-" {
  count = var.kube_storage_machine_count
  name  = "storage-disk-c-${count.index}-data"
  type  = var.kube_storage_disk_type
  zone  = var.zone
  size  = var.kube_storage_disk_size
}

resource "google_compute_instance" "kube-storage" {
  count        = var.kube_storage_machine_count
  name         = "kube-storage-${count.index}"
  machine_type = var.kube_storage_machine_type

  #can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-storage"]

  boot_disk {
    initialize_params {
      image = var.ubuntu
      size  = var.boot_disk_size
    }
  }


  network_interface {
    subnetwork = google_compute_subnetwork.private-subnet.name
    #network_ip = "10.20.0.${count.index+3}"
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  attached_disk {
    source      = element(google_compute_disk.storage-disk-b-.*.self_link, count.index)
    device_name = element(google_compute_disk.storage-disk-b-.*.name, count.index)
  }

  attached_disk {
    source      = element(google_compute_disk.storage-disk-c-.*.self_link, count.index)
    device_name = element(google_compute_disk.storage-disk-c-.*.name, count.index)
  }

  metadata_startup_script = "apt-get install -y python"
}

## create ansible invertory file
data  "template_file" "k8s" {
    template = file("./templates/k8s.tpl")
    vars = {
        kube_master_name = join("\n", google_compute_instance.kube-master.*.name)
        kube_worker_name = join("\n", google_compute_instance.kube-worker.*.name)
        kube_storage_name = join("\n", google_compute_instance.kube-storage.*.name)
    }
}

resource "local_file" "k8s_file" {
  content  = data.template_file.k8s.rendered
  filename = "./inventory/k8s-host.ini"
}

data  "template_file" "ssh" {
    template = file("./templates/ssh.tpl")
    vars = {
        bastion_ip =  google_compute_address.bastion-ip-address.address
        bastion_ip =  google_compute_address.bastion-ip-address.address
    }
}

resource "local_file" "ssh_file" {
  content  = data.template_file.ssh.rendered
  filename = "./scripts/ssh.sh"
}



