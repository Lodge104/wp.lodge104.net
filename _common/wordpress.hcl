# Common Bitnami WordPress Helm chart defaults.
# Source: https://artifacthub.io/packages/helm/bitnami/wordpress
locals {
  chart         = "wordpress"
  repository    = "oci://registry-1.docker.io/bitnamicharts"
  chart_version = "32.1.1"
  release_name  = "wordpress"
  namespace     = "wordpress"

  # ---------------------------------------------------------------------------
  # Base Helm values applied to all environments.
  # Bundled MariaDB is disabled – Aurora MySQL Serverless (RDS) is used instead.
  # The externalDatabase.existingSecret must be a Kubernetes Secret with key
  # "mariadb-password" containing the Aurora DB user password.
  # Recommended: provision that secret via External Secrets Operator syncing
  # from AWS Secrets Manager (created alongside the RDS module).
  # ---------------------------------------------------------------------------
  base_values = <<-YAML
    mariadb:
      enabled: false

    wordpressScheme: https
    wordpressTablePrefix: wp_

    service:
      type: ClusterIP

    ingress:
      enabled: true
      ingressClassName: nginx
      pathType: Prefix
      tls: true
      annotations:
        nginx.ingress.kubernetes.io/ssl-redirect: "true"
        nginx.ingress.kubernetes.io/proxy-body-size: "64m"

    persistence:
      enabled: true
      storageClass: gp3

    metrics:
      enabled: true

    networkPolicy:
      enabled: true

    autoscaling:
      enabled: false
  YAML
}
