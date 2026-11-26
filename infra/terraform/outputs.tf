output "url" {
  value = "http://${var.ingress_host == "" ? "127.0.0.1" : var.ingress_host}:${var.http_port}"
}

output "kubeconfig" {
  value = kind_cluster.mural.kubeconfig_path
}
