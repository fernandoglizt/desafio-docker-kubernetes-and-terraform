locals {
  project = abspath("${path.module}/../..")
  chart   = abspath("${path.module}/../helm/mural")
  revision = sha256(join("", [
    for file in sort(tolist(fileset(local.chart, "**"))) : "${file}:${filesha256("${local.chart}/${file}")}"
  ]))
  images = {
    for component in ["api", "web"] : component => {
      repository = "local/${var.cluster_name}-${component}"
      version = substr(sha256(join("", concat(
        [filesha256("${local.project}/app/docker/${component}.Dockerfile")],
        [for file in sort(tolist(fileset("${local.project}/app/${component}", "**"))) :
          "${file}:${filesha256("${local.project}/app/${component}/${file}")}"
        ]
      ))), 0, 16)
      context    = "${local.project}/app/${component}"
      dockerfile = "${local.project}/app/docker/${component}.Dockerfile"
    }
  }
}

resource "kind_cluster" "mural" {
  name            = var.cluster_name
  node_image      = "kindest/node:v1.34.0"
  wait_for_ready  = true
  kubeconfig_path = "${abspath(path.root)}/.terraform/mural.kubeconfig"

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role   = "control-plane"
      labels = { ingress-ready = "true" }

      extra_port_mappings {
        container_port = 80
        host_port      = var.http_port
        listen_address = "127.0.0.1"
      }

      extra_port_mappings {
        container_port = 443
        host_port      = var.https_port
        listen_address = "127.0.0.1"
      }
    }
  }
}

resource "terraform_data" "build_image" {
  for_each = local.images
  input    = "${each.value.repository}:${each.value.version}"

  triggers_replace = ["${each.value.repository}:${each.value.version}"]

  provisioner "local-exec" {
    command = "docker build --file \"$MURAL_DOCKERFILE\" --tag \"$MURAL_IMAGE\" \"$MURAL_CONTEXT\""
    environment = {
      MURAL_DOCKERFILE = each.value.dockerfile
      MURAL_IMAGE      = self.input
      MURAL_CONTEXT    = each.value.context
    }
  }

  provisioner "local-exec" {
    when    = destroy
    command = "if docker image inspect \"$MURAL_IMAGE\" >/dev/null 2>&1; then docker image rm \"$MURAL_IMAGE\"; fi"
    environment = {
      MURAL_IMAGE = self.input
    }
  }
}

resource "kind_load" "image" {
  for_each     = local.images
  image        = terraform_data.build_image[each.key].output
  cluster_name = kind_cluster.mural.name

  lifecycle {
    replace_triggered_by = [kind_cluster.mural]
  }
}

resource "kubernetes_namespace_v1" "mural" {
  metadata {
    name = "mural"
  }
}

resource "random_password" "database" {
  length  = 32
  special = false
}

resource "helm_release" "traefik" {
  name            = "traefik"
  namespace       = "kube-system"
  repository      = "https://traefik.github.io/charts"
  chart           = "traefik"
  version         = "34.5.0"
  skip_crds       = true
  atomic          = true
  cleanup_on_fail = true

  values = [yamlencode({
    ingressClass = {
      enabled        = true
      isDefaultClass = false
      name           = "traefik"
    }
    providers = {
      kubernetesCRD     = { enabled = false }
      kubernetesIngress = { publishedService = { enabled = false } }
    }
    service      = { enabled = false }
    nodeSelector = { ingress-ready = "true" }
    ports = {
      web       = { hostPort = 80 }
      websecure = { hostPort = 443 }
    }
    resources = {
      requests = { cpu = "50m", memory = "48Mi" }
      limits   = { cpu = "250m", memory = "192Mi" }
    }
  })]
}

resource "helm_release" "mural" {
  name            = "mural"
  namespace       = kubernetes_namespace_v1.mural.metadata[0].name
  chart           = local.chart
  atomic          = true
  cleanup_on_fail = true
  wait_for_jobs   = true
  timeout         = 300

  values = [yamlencode({
    chartRevision = local.revision
    api = { image = {
      repository = local.images.api.repository
      tag        = local.images.api.version
    } }
    web = { image = {
      repository = local.images.web.repository
      tag        = local.images.web.version
    } }
    ingress = { host = var.ingress_host }
  })]

  set_sensitive {
    name  = "postgres.password"
    value = random_password.database.result
  }

  depends_on = [kind_load.image, helm_release.traefik]
}
