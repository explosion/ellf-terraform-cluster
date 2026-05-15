job "traefik" {
  datacenters = ["dc1"]
  type        = "service"

  group "traefik" {
    count = 1

    network {
      port "http" {
        static = 80
      }
      port "https" {
        static = 443
      }
      port "dashboard" {
        static = 8080
      }
    }

    task "traefik" {
      driver = "docker"

      config {
        image        = "traefik:${traefik_version}"
        network_mode = "host"

        args = [
          "--entrypoints.web.address=:80",
          "--entrypoints.websecure.address=:443",
          "--providers.nomad=true",
          "--providers.nomad.endpoint.address=http://127.0.0.1:4646",
          "--providers.nomad.exposedByDefault=false",
          "--api.dashboard=true",
          "--api.insecure=true",
        ]
      }

      resources {
        cpu    = 200
        memory = 256
      }

      service {
        name     = "traefik"
        port     = "http"
        provider = "nomad"
      }
    }
  }
}
