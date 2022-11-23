locals {
  default_helm_values = {
    "configs" = {
      "secret" = {
        "argocdServerAdminPassword" = htpasswd_password.argocd_admin_password.bcrypt
        "argocdServerAdminPasswordMtime" = "2020-07-23T11:31:23Z"
      }
    }
    controller = {
      metrics = {
        enabled = true
      }
    }
    dex = {
      enabled = false
    }
    repoServer = {
      metrics = {
        enabled = true
      }
    }
    server = {
      config = {
        "accounts.pipeline"       = "apiKey"
        "resource.customizations" = <<-EOT
          argoproj.io/Application:
            health.lua: |
              hs = {}
              hs.status = "Progressing"
              hs.message = ""
              if obj.status ~= nil then
                if obj.status.health ~= nil then
                  hs.status = obj.status.health.status
                  if obj.status.health.message ~= nil then
                    hs.message = obj.status.health.message
                  end
                end
              end
              return hs
          networking.k8s.io/Ingress:
            health.lua: |
              hs = {}
              hs.status = "Healthy"
              return hs
              EOT
        configManagementPlugins   = <<-EOT
              - name: kustomized-helm
                init:
                  command: ["/bin/sh", "-c"]
                  args: ["helm dependency build || true"]
                generate:
                  command: ["/bin/sh", "-c"]
                  args: ["echo \"$HELM_VALUES\" | helm template . --name-template $ARGOCD_APP_NAME --namespace $ARGOCD_APP_NAMESPACE $HELM_ARGS -f - --include-crds > all.yaml && kustomize build"]
                      EOT
      }
      ingress = {
        enabled = true
        annotations = {
          "cert-manager.io/cluster-issuer"                   = var.cluster_issuer
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          "traefik.ingress.kubernetes.io/router.tls"         = "true"
          "ingress.kubernetes.io/ssl-redirect"               = "true"
          "kubernetes.io/ingress.allow-http"                 = "false"
        }
        hosts = [
          "argocd.apps.${var.base_domain}",
        ]
        tls = [
          {
            secretName = "argocd-tls"
            hosts = [
              "argocd.apps.${var.base_domain}",
            ]
          },
        ]
      }
    }
  }
}

resource "random_password" "argocd_admin_password" {
  length  = 30
  special = false
}

resource "htpasswd_password" "argocd_admin_password" {
  password = random_password.argocd_admin_password.result
}

data "utils_deep_merge_yaml" "values" {
  input = [
    yamlencode(local.default_helm_values),
    var.raw_helm_values,
    yamlencode(var.helm_values),
  ]
}

resource "kubernetes_namespace" "this" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace.this.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"

  chart   = "argo-cd"
  version = var.chart_version

  skip_crds = "true"

  set {
    name = "crds.install"
    value = "false"
  }

  values = [data.utils_deep_merge_yaml.values.output]
}
