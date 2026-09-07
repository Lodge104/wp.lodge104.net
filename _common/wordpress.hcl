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

    updateStrategy:
      type: RollingUpdate
      rollingUpdate:
        maxSurge: 0
        maxUnavailable: 1

    # WP Offload Media uses the EKS node instance profile instead of static
    # credentials. The CDN bucket remains private and is delivered by CloudFront.
    wordpressExtraConfigContent: |
      define( 'AS3CF_SETTINGS', serialize( array(
          'provider' => 'aws',
          'use-server-roles' => true,
      ) ) );

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

    # The default readinessProbe targets the port named after wordpressScheme
    # (here "https" -> 8443), but Apache never actually terminates TLS -- the
    # ALB does that and forwards plain HTTP to the pod. Point the probe at
    # the real listening port instead, otherwise it never becomes Ready.
    # readinessProbe:
    #   httpGet:
    #     port: http
    #     scheme: HTTP

    # Native chart multisite support (maps to WORDPRESS_ENABLE_MULTISITE and
    # friends). Unlike hand-rolling the MULTISITE/DOMAIN_CURRENT_SITE
    # defines via wordpressExtraConfigContent, this lets the entrypoint run
    # `wp core multisite-install` instead of a plain single-site install, so
    # the network's primary site actually gets created instead of erroring
    # with "Site not found" on first boot. multisite.host is set per
    # environment.
    multisite:
      enable: true
      networkType: subdomain

    metrics:
      enabled: true

    networkPolicy:
      enabled: true

    autoscaling:
      enabled: true
  YAML
}
