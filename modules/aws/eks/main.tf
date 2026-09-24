# ----------------------------
# IAM – EKS cluster role
# ----------------------------

resource "aws_iam_role" "eks_cluster" {
  name = "${var.prefix}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
}

# ----------------------------
# IAM – Node group role
# ----------------------------

resource "aws_iam_role" "eks_nodes" {
  name = "${var.prefix}-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# ----------------------------
# Security group – nodes
# ----------------------------

resource "aws_security_group" "eks_nodes" {
  name   = "${var.prefix}-eks-nodes-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ----------------------------
# EKS cluster
# ----------------------------

resource "aws_eks_cluster" "primary" {
  name     = "${var.prefix}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.cluster_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_nodes.id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# ----------------------------
# EFS CSI driver addon
# ----------------------------

resource "aws_eks_addon" "efs_csi" {
  cluster_name = aws_eks_cluster.primary.name
  addon_name   = "aws-efs-csi-driver"

  # At provision time the tainted system node is often the only node in the
  # cluster (worker pools default to min_size 0), so the controller must
  # tolerate the system taint or the addon hangs DEGRADED with its pods
  # unschedulable until the terraform timeout.
  configuration_values = jsonencode({
    controller = {
      tolerations = [
        {
          key      = "ellf/role"
          value    = "system"
          effect   = "NoSchedule"
          operator = "Equal"
        },
        {
          key      = "CriticalAddonsOnly"
          operator = "Exists"
        },
      ]
    }
  })

  depends_on = [aws_eks_node_group.system]
}

# ----------------------------
# Workload identity – EKS Pod Identity
# ----------------------------

# Pods running as the cluster's Kubernetes service account (the broker and
# the recipe Jobs it launches) assume this role, the counterpart of GKE
# Workload Identity in modules/gcp/gke and AKS workload identity in
# modules/azure/aks. Nodes keep only their node role, so storage access is
# scoped to that one service account rather than to anything on the node.
resource "aws_eks_addon" "pod_identity" {
  cluster_name = aws_eks_cluster.primary.name
  addon_name   = "eks-pod-identity-agent"
}

resource "aws_iam_role" "workload" {
  name = "${var.prefix}-eks-workload-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}

# Object read/write plus bucket listing on the cluster's data storage, the
# same access the gcp and azure modules grant.
resource "aws_iam_role_policy" "workload_buckets" {
  count = length(var.buckets) > 0 ? 1 : 0
  name  = "${var.prefix}-eks-workload-buckets"
  role  = aws_iam_role.workload.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [for b in var.buckets : "arn:aws:s3:::${b}"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = [for b in var.buckets : "arn:aws:s3:::${b}/*"]
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "workload" {
  cluster_name    = aws_eks_cluster.primary.name
  namespace       = var.k8s_namespace
  service_account = var.k8s_service_account
  role_arn        = aws_iam_role.workload.arn

  depends_on = [aws_eks_addon.pod_identity]
}

# ----------------------------
# System node group
# ----------------------------

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.system_node_pool_instance_type]

  scaling_config {
    desired_size = var.system_node_pool_size
    min_size     = var.system_node_pool_size
    max_size     = var.system_node_pool_size
  }

  labels = {
    "ellf/role" = "system"
  }

  # Reserve the system pool for platform components (broker, traefik,
  # cert-manager, NFS). Recipe Jobs lack this toleration and therefore
  # cannot accidentally schedule here when their worker_type doesn't
  # resolve or a customer leaves --worker-class unset. Mirrors the taint
  # on the GKE system node pool (modules/gcp/gke/main.tf).
  taint {
    key    = "ellf/role"
    value  = "system"
    effect = "NO_SCHEDULE"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]
}

# ----------------------------
# Worker node groups
# ----------------------------

resource "aws_eks_node_group" "workers" {
  for_each = var.worker_types

  cluster_name    = aws_eks_cluster.primary.name
  node_group_name = each.value.name
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [each.value.instance_type]
  capacity_type   = each.value.spot ? "SPOT" : "ON_DEMAND"
  # AL2 AMI types are rejected on Kubernetes >= 1.33 (and Amazon Linux 2 is
  # EOL), so worker pools must use AL2023 to run on any cluster_version AWS
  # still supports. The GPU variant is AL2023_x86_64_NVIDIA — the naming
  # scheme differs from AL2's "_GPU" suffix.
  ami_type = each.value.gpu != null ? "AL2023_x86_64_NVIDIA" : "AL2023_x86_64_STANDARD"

  scaling_config {
    desired_size = each.value.min_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  labels = {
    "ellf/node-class" = each.value.node_class
    "ellf/worker"     = "true"
  }

  dynamic "taint" {
    for_each = each.value.gpu != null ? [1] : []
    content {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ecr_read_only,
  ]
}
