variable "argocd_namespace" {
  type = string
  default = ""
}

variable "base_domain" {
  type = string
  default = ""
}

variable "cluster_issuer" {
  type = string
  default = ""
}

variable "chart_version" {
  type = string
}

variable "raw_helm_values" {
  type = string
  default = "{}"
}

variable "helm_values" {
  type = any
  default = {}
}
