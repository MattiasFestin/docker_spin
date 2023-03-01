job "hippo" {
  datacenters = ["dc1"]
  type        = "service"

  constraint {
    attribute = "${attr.kernel.name}"
    value     = "linux"
  }

  group "hippo" {
    count = 1

    network {
      port "http" {
        static = 5000
      }
    }

    service {
      name = "hippo"
      port = "http"

      tags = [
        "traefik.enable=true",
        "traefik.http.routers.hippo.rule=Host(`hippo.localhost`)",
        "traefik.http.routers.hippo.entryPoints=web",
        "traefik.http.services.hippo.loadbalancer.server.port=5000"
      ]

      check {
        name     = "alive"
        type     = "tcp"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "hippo" {
      driver = "raw_exec"

      env {
        Hippo__PlatformDomain = "hippo.localhost"
        Scheduler__Driver     = "nomad"

        # Registration configuration
        Hippo__RegistrationMode            = "AdministratorOnly"
        Hippo__Administrators__0__Username = "admin"
        Hippo__Administrators__0__Password = "password"

        # Database Driver: inmemory, sqlite, postgresql
        Database__Driver            = "sqlite"
        ConnectionStrings__Database = "Data Source=hippo.db;Cache=Shared"

        ConnectionStrings__Bindle     = "server=http://localhost:8080/v1"

        Nomad__Traefik__Entrypoint   = "web"
        Nomad__Traefik__CertResolver = ""

        Jwt__Key      = "081cc557-2b32-4ddb-b289-59a26cb22c4c"
        Jwt__Issuer   = "localhost"
        Jwt__Audience = "localhost"

        Kestrel__Endpoints__Https__Url = "http://${NOMAD_ADDR_http}"
      }

      config {
        command = "bash"
        args    = ["-c", "cd /root/hippo/linux-x64 && ./Hippo.Web"]
      }
    }
  }
}
