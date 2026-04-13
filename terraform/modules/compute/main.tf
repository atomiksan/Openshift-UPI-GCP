locals {
  ignition_base_url = trimsuffix(var.ignition_base_url, "/")

  bootstrap_user_data = var.ignition_mode == "file" ? file("${var.ignition_dir}/bootstrap.ign") : jsonencode({
    ignition = {
      version = var.ignition_version
      config = {
        merge = [
          {
            source = "${local.ignition_base_url}/bootstrap.ign"
          }
        ]
      }
    }
  })

  master_user_data = var.ignition_mode == "file" ? file("${var.ignition_dir}/master.ign") : jsonencode({
    ignition = {
      version = var.ignition_version
      config = {
        merge = [
          {
            source = "${local.ignition_base_url}/master.ign"
          }
        ]
      }
    }
  })

  worker_user_data = var.ignition_mode == "file" ? file("${var.ignition_dir}/worker.ign") : jsonencode({
    ignition = {
      version = var.ignition_version
      config = {
        merge = [
          {
            source = "${local.ignition_base_url}/worker.ign"
          }
        ]
      }
    }
  })

  common_node_tags = ["${var.cluster_id}-openshift", "${var.cluster_id}-node"]
  master_names     = ["master0", "master1", "master2"]
  worker_names     = ["worker0", "worker1"]
}

resource "google_compute_instance" "bastion" {
  name         = "${var.cluster_id}-bastion"
  machine_type = "e2-medium"
  tags         = ["${var.cluster_id}-bastion"]
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.bastion_image
      size  = 50
      type  = "pd-balanced"
    }
  }

  network_interface {
    network_ip = var.reserved_ips["bastion"]
    subnetwork = var.nodes_subnet_id

    dynamic "access_config" {
      for_each = var.bastion_enable_public_ip ? [1] : []
      content {}
    }
  }

  metadata_startup_script = templatefile("${path.module}/templates/bastion-startup.sh.tftpl", {
    bootstrap_ip           = var.reserved_ips["bootstrap"]
    master0_ip             = var.reserved_ips["master0"]
    master1_ip             = var.reserved_ips["master1"]
    master2_ip             = var.reserved_ips["master2"]
    haproxy_stats_user     = var.haproxy_stats_user
    haproxy_stats_password = var.haproxy_stats_password
  })
}

resource "google_compute_instance" "bootstrap" {
  name         = "${var.cluster_id}-bootstrap"
  machine_type = "n2-standard-4"
  tags         = concat(local.common_node_tags, ["${var.cluster_id}-bootstrap"])
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.rhcos_image
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network_ip = var.reserved_ips["bootstrap"]
    subnetwork = var.nodes_subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.bootstrap_user_data
  }
}

resource "google_compute_instance" "master" {
  for_each = toset(local.master_names)

  name         = "${var.cluster_id}-${each.key}"
  machine_type = "n2-standard-4"
  tags         = concat(local.common_node_tags, ["${var.cluster_id}-master"])
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.rhcos_image
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network_ip = var.reserved_ips[each.key]
    subnetwork = var.nodes_subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.master_user_data
  }
}

resource "google_compute_instance" "worker" {
  for_each = toset(local.worker_names)

  name         = "${var.cluster_id}-${each.key}"
  machine_type = "n2-standard-4"
  tags         = concat(local.common_node_tags, ["${var.cluster_id}-worker"])
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = var.rhcos_image
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network_ip = var.reserved_ips[each.key]
    subnetwork = var.nodes_subnet_id
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  metadata = {
    user-data = local.worker_user_data
  }
}
