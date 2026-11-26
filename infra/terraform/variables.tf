variable "cluster_name" {
  type    = string
  default = "mural"
}

variable "ingress_host" {
  type    = string
  default = "mural.localtest.me"
}

variable "http_port" {
  type    = number
  default = 8080
}

variable "https_port" {
  type    = number
  default = 8443
}
