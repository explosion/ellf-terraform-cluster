# ----------------------------
# EFS file system (NFS)
# ----------------------------

resource "aws_efs_file_system" "nfs" {
  creation_token   = "${var.prefix}-efs"
  performance_mode = var.efs_performance_mode
  throughput_mode  = var.efs_throughput_mode
  encrypted        = true

  tags = {
    Name = "${var.prefix}-efs"
  }
}

resource "aws_security_group" "efs" {
  name   = "${var.prefix}-efs-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_efs_mount_target" "nfs" {
  for_each = toset(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.nfs.id
  subnet_id       = each.value
  security_groups = [aws_security_group.efs.id]
}

# ----------------------------
# Kubernetes provider
# ----------------------------

data "aws_eks_cluster_auth" "default" {
  name = aws_eks_cluster.primary.name
}

provider "kubernetes" {
  host                   = aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

# ----------------------------
# Kubernetes namespace
# ----------------------------

resource "kubernetes_namespace_v1" "app" {
  metadata {
    name = var.k8s_namespace
  }

  depends_on = [aws_eks_node_group.system]
}

# ----------------------------
# EFS storage class + PV/PVC
# ----------------------------

resource "kubernetes_storage_class_v1" "efs" {
  metadata {
    name = "efs"
  }

  storage_provisioner = "efs.csi.aws.com"
  reclaim_policy      = "Retain"

  depends_on = [aws_eks_addon.efs_csi]
}

resource "kubernetes_persistent_volume_v1" "efs" {
  metadata {
    name = "${var.prefix}-efs-pv"
  }

  spec {
    capacity = {
      storage = "${var.efs_capacity_gb}Gi"
    }

    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.efs.metadata[0].name

    persistent_volume_source {
      csi {
        driver        = "efs.csi.aws.com"
        volume_handle = aws_efs_file_system.nfs.id
      }
    }
  }

  depends_on = [aws_efs_mount_target.nfs]
}

resource "kubernetes_persistent_volume_claim_v1" "efs" {
  metadata {
    name      = "prodigy-nfs"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteMany"]
    storage_class_name = kubernetes_storage_class_v1.efs.metadata[0].name

    resources {
      requests = {
        storage = "${var.efs_capacity_gb}Gi"
      }
    }

    volume_name = kubernetes_persistent_volume_v1.efs.metadata[0].name
  }
}
