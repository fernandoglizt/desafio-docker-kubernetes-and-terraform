terraform {
  required_version = ">= 1.5"

  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "0.13.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}

provider "kubernetes" {
  host                   = kind_cluster.mural.endpoint
  client_certificate     = kind_cluster.mural.client_certificate
  client_key             = kind_cluster.mural.client_key
  cluster_ca_certificate = kind_cluster.mural.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = kind_cluster.mural.endpoint
    client_certificate     = kind_cluster.mural.client_certificate
    client_key             = kind_cluster.mural.client_key
    cluster_ca_certificate = kind_cluster.mural.cluster_ca_certificate
  }
}
