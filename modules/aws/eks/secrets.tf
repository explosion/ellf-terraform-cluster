# ----------------------------
# Broker RSA keypair + K8s Secret
# ----------------------------

resource "tls_private_key" "broker" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "kubernetes_secret_v1" "infra" {
  metadata {
    name      = "prodigy-teams-infra"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }

  data = {
    PRODIGY_TEAMS_DATABASE_HOST     = var.database_host
    PRODIGY_TEAMS_DATABASE_NAME     = var.database_name
    PRODIGY_TEAMS_DATABASE_USER     = var.database_user
    PRODIGY_TEAMS_DATABASE_PASSWORD = var.database_password
    PRODIGY_TEAMS_PRIVATE_KEY       = base64encode(tls_private_key.broker.private_key_pem)
    PRODIGY_TEAMS_PUBLIC_KEY        = base64encode(tls_private_key.broker.public_key_pem)
  }

  depends_on = [kubernetes_namespace_v1.app]
}
