provider "google" {
  credentials = "${file("${var.credentials}")}"
  project     = "${var.var_project}"
  region      = "${var.region}"
  zone        = "${var.zone}"
}

resource "google_compute_network" "vpc" {
  name          =  "${var.vpc}"
  auto_create_subnetworks = "false"
  routing_mode            = "GLOBAL"
}


resource "google_compute_subnetwork" "public-subnet" {
  name            = "public-subnet"
  network         = "${google_compute_network.vpc.name}"
  ip_cidr_range   = "${var.gce_public_subnet_cidr}"
}

resource "google_compute_subnetwork" "private-subnet" {
  name            = "private-subnet"
  network         = "${google_compute_network.vpc.name}"
  ip_cidr_range   = "${var.gce_private_subnet_cidr}"
}


resource "google_compute_router" "router" {
  name    = "router"
  region  = "${google_compute_subnetwork.private-subnet.region}"
  network = "${google_compute_network.vpc.self_link}"
  bgp {
    asn = 64514
  }
}

resource "google_compute_router_nat" "simple-nat" {
  name                               = "nat-1"
  router                             = "${google_compute_router.router.name}"
  region                             = "${var.region}"
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}


resource "google_compute_firewall" "private-firewall" {
  name    = "private-firewall"
  network = "${google_compute_network.vpc.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = [ "${var.gce_public_subnet_cidr}","${var.gce_private_subnet_cidr}" ]
}

resource "google_compute_firewall" "public-firewall" {
  name    = "public-firewall"
  network = "${google_compute_network.vpc.name}"

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
  }

  source_ranges = [ "0.0.0.0/0" ]
}

resource "google_compute_address" "bastion-ip-address" {
  count = "${var.bastion-ip-address-count}"
  name = "bastion-ip-address-${count.index}"
}

resource "google_compute_instance" "bastion" {
  count = "${var.bastion-ip-address-count}"
  name            = "bastion-${count.index}"
  machine_type    = "n1-standard-1"
  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way","bastion"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.public-subnet.name}"
    network_ip = "10.10.0.${count.index+2}"

    access_config {
      // Ephemeral IP
    }
  }

  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }

  metadata_startup_script = "apt-get install -y python"

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}" 
  }


  network_interface {
    network = "default"
    access_config {
      nat_ip = "${google_compute_address.bastion-ip-address[count.index].address}"
    }
  }

}

resource "google_compute_instance" "controller" {
  count = 1
  name            = "controller-${count.index}"
  machine_type    = "n1-standard-1"
  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way","controller"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.public-subnet.name}"
    network_ip = "10.10.0.${count.index+4}"

  }

  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  metadata_startup_script = "apt-get install -y python"
}



resource "google_compute_instance" "worker" {
  count = 1
  name            = "worker-${count.index}"
  machine_type    = "n1-standard-1"
  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way","worker"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

  // Local SSD disk
  scratch_disk {
  }

  network_interface {
    subnetwork = "${google_compute_subnetwork.private-subnet.name}"
    network_ip = "10.20.0.${count.index+3}"

  }

  service_account {
    scopes = ["compute-rw","storage-ro","service-management","service-control","logging-write","monitoring"]
  }

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }

  metadata_startup_script = "apt-get install -y python"
}
