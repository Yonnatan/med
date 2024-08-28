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


resource "kubernetes_manifest" "prometheus_serviceaccount" {
  manifest = yamldecode(file("${path.module}/deployment/permissions/prometheus-serviceaccount.yaml"))
  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "prometheus_clusterrole" {
  manifest = yamldecode(file("${path.module}/deployment/permissions/prometheus-clusterrole.yaml"))
  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "prometheus_clusterrolebinding" {
  manifest = yamldecode(file("${path.module}/deployment/permissions/prometheus-clusterrolebinding.yaml"))
  depends_on = [kubernetes_manifest.prometheus_serviceaccount, kubernetes_manifest.prometheus_clusterrole]
}
resource "kubernetes_manifest" "prometheus_config" {
  manifest = yamldecode(file("${path.module}/deployment/prometheus-configmap.yaml"))

  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "prometheus_deployment" {
  manifest = yamldecode(file("${path.module}/deployment/prometheus-deployment.yaml"))

  depends_on = [kubernetes_manifest.prometheus_config,kubernetes_manifest.prometheus_clusterrolebinding]
}

resource "kubernetes_manifest" "prometheus_service" {
  manifest = yamldecode(file("${path.module}/deployment/prometheus-service.yaml"))

  depends_on = [kubernetes_manifest.prometheus_deployment,null_resource.check_namespace]
}

resource "kubernetes_manifest" "grafana_deployment" {
  manifest = yamldecode(file("${path.module}/deployment/grafana-deployment.yaml"))

  depends_on = [null_resource.check_namespace]
}

resource "kubernetes_manifest" "grafana_service" {
  manifest = yamldecode(file("${path.module}/deployment/grafana-service.yaml"))

  depends_on = [kubernetes_manifest.grafana_deployment,null_resource.check_namespace]
}