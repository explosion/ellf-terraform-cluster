# ----------------------------
# Broker RSA keypair + K8s Secret
# ----------------------------

resource "tls_private_key" "broker" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "kubernetes_secret_v1" "infra" {
  count = local.in_cluster ? 1 : 0
  metadata {
    name      = local.infra_secret_name
    namespace = kubernetes_namespace_v1.app[0].metadata[0].name
  }

  data = {
    ELLF_DATABASE_PASSWORD = var.database_password
    ELLF_PRIVATE_KEY       = base64encode(tls_private_key.broker.private_key_pem)
    ELLF_PUBLIC_KEY        = base64encode(tls_private_key.broker.public_key_pem)
  }

  depends_on = [kubernetes_namespace_v1.app]
}

locals {
  infra_secret_name = "ellf-infra"
}

moved {
  from = kubernetes_secret_v1.infra
  to   = kubernetes_secret_v1.infra[0]
}
