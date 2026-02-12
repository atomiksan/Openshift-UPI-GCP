# MASTER NODES
resource "google_compute_instance" "master" {
  count        = 3
  name         = "${var.cluster_id}-master-${count.index}"
  machine_type = "n2-standard-4"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = var.rhcos_image
      size  = 100
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.nodes_subnet_id
    # Masters stay private
  }

  service_account {
    email  = "ocp-installer-sa@vernal-branch-484810-p6.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = file("${path.root}/../ocp-install-config/master.ign")
  }
}

# BOOTSTRAP NODE
resource "google_compute_instance" "bootstrap" {
  name         = "${var.cluster_id}-bootstrap"
  machine_type = "n2-standard-4"
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = var.rhcos_image
      size  = 100
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = var.nodes_subnet_id
    access_config {} # Public IP for bootstrap
  }

  service_account {
    email  = "ocp-installer-sa@vernal-branch-484810-p6.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }


  metadata = {
    user-data = jsonencode({
      ignition = {
        config = {
          replace = {
            source = "https://storage.googleapis.com/ocp-ignition-1769516257/bootstrap.ign"
          }
        }
        version = "3.4.0"
      }
    })
  }
}
