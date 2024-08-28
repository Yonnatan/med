# Check if the namespace exists
resource "null_resource" "check_namespace" {
  triggers = {
    name = var.cluster_namespace
  }

  provisioner "local-exec" {
    command = <<EOF
      kubectl get namespace ${var.cluster_namespace} || kubectl create namespace ${var.cluster_namespace}
    EOF
  }
}


resource "kubernetes_config_map" "nginx_config" {
  metadata {
    name      = "nginx-config"
    namespace = var.cluster_namespace
  }

  data = {
    "status.conf" = file("${path.module}/deployment/configmap.yaml")
  }

  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "hello_world_deployment" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "hello-world"
      namespace = var.cluster_namespace
    }
    spec = yamldecode(file("${path.module}/deployment/deployment.yaml"))["spec"]
  }
  depends_on = [kubernetes_config_map.nginx_config]
}

resource "kubernetes_manifest" "hello_world_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "hello-world-service"
      namespace = var.cluster_namespace
    }
    spec = yamldecode(file("${path.module}/deployment/hello-world-service.yaml"))["spec"]
  }
  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "hello_world_metrics_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "hello-world-service"
      namespace = var.cluster_namespace
    }
    spec = yamldecode(file("${path.module}/deployment/hello-world-metrics-service.yaml"))["spec"]
  }
  depends_on = [null_resource.check_namespace]
}


data "kubernetes_service" "hello_world" {
  metadata {
    name      = "hello-world-service"
    namespace = var.cluster_namespace
  }

  depends_on = [kubernetes_manifest.hello_world_service]
}


