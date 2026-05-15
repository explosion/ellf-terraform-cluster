# ----------------------------
# Filestore NFS instance
# ----------------------------

resource "google_filestore_instance" "nfs" {
  name     = "${var.prefix}-nomad-nfs"
  location = var.gcp_zone
  tier     = var.filestore_tier

  file_shares {
    capacity_gb = var.filestore_capacity_gb
    name        = var.filestore_share_name
  }

  networks {
    network = var.network_name
    modes   = ["MODE_IPV4"]
  }
}
