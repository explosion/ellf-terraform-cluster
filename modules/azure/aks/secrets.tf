# ----------------------------
# Broker RSA keypair + K8s Secret
# ----------------------------

resource "tls_private_key" "broker" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "kubernetes_secret_v1" "infra" {
  metadata {
    name      = "ellf-infra"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  data = {
    ELLF_DATABASE_PASSWORD = var.database_password
    ELLF_PRIVATE_KEY       = base64encode(tls_private_key.broker.private_key_pem)
    ELLF_PUBLIC_KEY        = base64encode(tls_private_key.broker.public_key_pem)
  }

  depends_on = [kubernetes_namespace_v1.app]
}
