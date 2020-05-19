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

################################   ##subnet and route ##########################

resource "google_compute_subnetwork" "public-subnet" {
  name          = "${var.vpc}-public-subnet"
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.gce_public_subnet_cidr
}

resource "google_compute_subnetwork" "private-subnet" {
  name          = "${var.vpc}-private-subnet"
  network       = google_compute_network.vpc.name
  ip_cidr_range = var.gce_private_subnet_cidr
}

resource "google_compute_router" "router" {
  name    = "${var.vpc}-router"
  region  = google_compute_subnetwork.private-subnet.region
  network = google_compute_network.vpc.self_link
  bgp {
    asn = 64514
  }
}


################################ nat  ############################

resource "google_compute_router_nat" "simple-nat" {
  name                               = "${var.vpc}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}


################################ fire wall ############################


resource "google_compute_firewall" "private-firewall" {
  name    = "${var.vpc}-private-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "tcp"
     ports    = ["0-65535"]
  }

  allow {
    protocol = "ipip"
  }

  source_ranges = [var.gce_public_subnet_cidr, var.gce_private_subnet_cidr, "130.211.0.0/22",  "35.191.0.0/16"]
}

resource "google_compute_firewall" "public-firewall" {
  name    = "${var.vpc}-public-firewall"
  network = google_compute_network.vpc.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "tcp"
    ports    = ["22","80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

########################### bastion ############################ 




resource "google_compute_address" "bastion-ip-address" {
  #count = var.bastion-ip-address-count
  #name  = "bastion-ip-address-${count.index}"
  name  = "${var.vpc}-bastion-ip-address"
}

resource "google_compute_instance" "bastion" {
  #count        = var.bastion-ip-address-count
  #name         = "bastion-${count.index}"
  name         = "${var.vpc}-bastion"
  machine_type = var.bastion_machine_type

  #can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "bastion"]

  boot_disk {
    initialize_params {
      image = var.os
      size  = var.boot_disk_size
    }
  }


  network_interface {
    subnetwork = google_compute_subnetwork.public-subnet.name

    #network_ip = "10.10.0.${count.index+2}"

    access_config {
      nat_ip  = google_compute_address.bastion-ip-address.address
      #nat_ip  = element(google_compute_address.bastion-ip-address.*.address, count.index)
    }
  }

  service_account {
    scopes = ["compute-rw", "storage-ro", "service-management", "service-control", "logging-write", "monitoring"]
  }

  metadata_startup_script = "sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; systemctl restart sshd; yum -y update; yum install -y git;  yum install -y ansible; git clone https://github.com/reza-rahim/kubeadm-ansible.git"

  metadata = {
    sshKeys = "${var.gce_ssh_user}:${file(var.gce_ssh_pub_key_file)}"
  }
}

########################### kube master ############################

resource "google_compute_instance" "kube-master" {
  count        = var.kube_master_machine_count
  name         = "${var.vpc}-master-${count.index}"
  machine_type = var.kube_master_machine_type

  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-master"]

  boot_disk {
    initialize_params {
      image = var.os
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

  metadata_startup_script = "sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; systemctl restart sshd; yum -y update; "
}


##### ----- #####
resource "google_compute_instance_group" "kube-master-inst-group" {
  
  name        = "${var.vpc}-kube-master-inst-group"
  description = "kube master load balancer"

  instances = [
    google_compute_instance.kube-master[0].self_link
    #for kube-master in google_compute_instance.kube-master:
    #   kube-master.self_link
  ]


  named_port {
    name = "https"
    port = "6443"
  }

  zone = var.zone
}

resource "google_compute_health_check" "tcp-health-check" {
  name = "${var.vpc}-tcp-health-check"
  
  tcp_health_check {
    port = "6443"
  }
}

## load balancer kube-master-lb

resource "google_compute_region_backend_service" "kube-master-lb" {
  name          = "${var.vpc}-master-lb"
  health_checks = [google_compute_health_check.tcp-health-check.self_link]
  region        = var.region

  backend {
    group = google_compute_instance_group.kube-master-inst-group.self_link
  }
}

resource "google_compute_forwarding_rule" "kube-master-lb-forwarding-rule" {
  name                  = "${var.vpc}-master-lb-forwarding-rule"
  load_balancing_scheme = "INTERNAL"
  ports                 = ["8080", "6443"]
  network               = google_compute_network.vpc.self_link
  subnetwork            = google_compute_subnetwork.private-subnet.self_link
  backend_service       = google_compute_region_backend_service.kube-master-lb.self_link
}


###################### ingress ####################


  resource "google_compute_instance" "kube-ingress" {
  count        = var.kube_ingress_machine_count
  name         = "${var.vpc}-ingress-${count.index}"
  machine_type = var.kube_ingress_machine_type

  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-ingress"]

  boot_disk {
    initialize_params {
      image = var.os
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

  metadata_startup_script = "sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; systemctl restart sshd; yum -y update; "
}

resource "google_compute_instance_group" "kube-ingress-inst-group" {
  
  name        = "${var.vpc}-kube-ingress-inst-group"
  description = "kube ingress load balancer"

  instances = [
  
    for kube-ingress in google_compute_instance.kube-ingress:
       kube-ingress.self_link
  ]

  named_port {
    name = "https"
    port = "32000"
  }

  zone = var.zone
}



###################### kube worker #################################

resource "google_compute_instance" "kube-worker" {
  count        = var.kube_worker_machine_count
  name         = "${var.vpc}-worker-${count.index}"
  machine_type = var.kube_worker_machine_type

  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-worker"]

  boot_disk {
    initialize_params {
      image = var.os
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

  metadata_startup_script = "sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; systemctl restart sshd; yum -y update;"
}


###################### kube storage #################################

resource "google_compute_disk" "storage-disk-b-" {
  count = var.kube_storage_machine_count
  name  = "${var.vpc}-storage-disk-b-${count.index}-data"
  type  = "pd-standard"
  zone  = var.zone
  size  = "500"
}

resource "google_compute_disk" "storage-disk-c-" {
  count = var.kube_storage_machine_count
  name  = "${var.vpc}-storage-disk-c-${count.index}-data"
  type  = "pd-standard"
  zone  = var.zone
  size  = "1000"
}

resource "google_compute_disk" "storage-disk-d-" {
  count = var.kube_storage_machine_count
  name  = "${var.vpc}-storage-disk-d-${count.index}-data"
  type  = "pd-standard"
  zone  = var.zone
  size  = "1000"
}


resource "google_compute_instance" "kube-storage" {
  count        = var.kube_storage_machine_count
  name         = "${var.vpc}-storage-${count.index}"
  machine_type = var.kube_storage_machine_type

  can_ip_forward  = true

  tags = ["kubernetes-the-easy-way", "kube-storage"]

  boot_disk {
    initialize_params {
      image = var.os
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

   attached_disk {
    source      = element(google_compute_disk.storage-disk-d-.*.self_link, count.index)
    device_name = element(google_compute_disk.storage-disk-d-.*.name, count.index)
  }

  metadata_startup_script = "sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config; systemctl restart sshd; yum -y update; "
}

####################### create ansible invertory file  ####################### 
data  "template_file" "k8s" {
    template = file("./templates/k8s.tpl")
    vars = {
        kube_master_name = join("\n", google_compute_instance.kube-master.*.name)
        kube_worker_name = join("\n", google_compute_instance.kube-worker.*.name)
        kube_storage_name = join("\n", google_compute_instance.kube-storage.*.name)
        kube_ingress_name = join("\n", google_compute_instance.kube-ingress.*.name)
    }
}

resource "local_file" "k8s_file" {
  content  = data.template_file.k8s.rendered
  filename = "./inventory/inventory.ini"
}


####################### create ssh files  ####################### 

data  "template_file" "ssh" {
    template = file("./templates/ssh.tpl")
    vars = {
        bastion_ip =  google_compute_address.bastion-ip-address.address
        bastion_ip =  google_compute_address.bastion-ip-address.address
        kube_master_lb = google_compute_forwarding_rule.kube-master-lb-forwarding-rule.ip_address
    }
}

resource "local_file" "ssh_file" {
  content  = data.template_file.ssh.rendered
  filename = "./scripts/ssh.sh"
}


