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
      ingressClassName: alb
      pathType: Prefix
      tls: false
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/backend-protocol: HTTP
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS": 443}]'
        # ALB health checks hit the pod directly over plain HTTP with no
        # X-Forwarded-Proto header. Since wordpressScheme is https, WordPress
        # issues a 301 canonical redirect to https for that request, which
        # would otherwise mark the target unhealthy (expected 200). Accept
        # the redirect as a pass.
        alb.ingress.kubernetes.io/success-codes: "200-399"

    persistence:
      enabled: true
      storageClass: efs-sc
      accessModes:
        - ReadWriteMany

    metrics:
      enabled: true

    networkPolicy:
      enabled: true

    autoscaling:
      enabled: true
  YAML
}
