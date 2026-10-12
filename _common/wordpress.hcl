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
      define('WP_CACHE', true);

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

    # The ALB terminates TLS and forwards plain HTTP to the pod; keep health
    # probes on the actual in-pod HTTP listener to avoid slow/unreliable pod
    # readiness during scale-out.
    readinessProbe:
      httpGet:
        port: http
        scheme: HTTP
    startupProbe:
      enabled: true
      httpGet:
        port: http
        scheme: HTTP

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

    # Self-healing fix for a prod outage on 2026-10-12: the Bitnami entrypoint
    # bakes DB_PASSWORD as a literal string into the persisted wp-config.php
    # at first install, and can never rewrite it afterwards (wp-config.php
    # ends up 444/owned by uid 50000, unwritable by the uid-1001 runtime
    # user, and wordpressSkipInstall further skips re-templating). If the
    # RDS master password is ever reset out-of-band, every pod starts
    # failing "Access denied for user" against MySQL and the whole site
    # goes down, with no amount of pod restarts fixing it, because new pods
    # restore the same stale persisted file from the shared EFS volume.
    #
    # This sidecar polls the persisted wp-config.php and -- if it still has
    # a literal DB_PASSWORD -- rewrites it to read the password from the
    # already-mounted WORDPRESS_DATABASE_PASSWORD_FILE secret at runtime
    # instead, on every PHP request. That way a future credential rotation
    # just works without needing another manual fix like this one did.
    sidecars:
      - name: wp-config-db-password-fix
        image: registry-1.docker.io/bitnami/wordpress:latest
        securityContext:
          runAsUser: 0
          runAsNonRoot: false
          allowPrivilegeEscalation: false
        resources:
          requests:
            cpu: 10m
            memory: 32Mi
          limits:
            cpu: 100m
            memory: 64Mi
        volumeMounts:
          - name: wordpress-data
            mountPath: /bitnami/wordpress
            subPath: wordpress
        command:
          - /bin/bash
          - -ec
          - |
            CONF=/bitnami/wordpress/wp-config.php
            MARKER="file_get_contents( '/secrets/mariadb-password' )"
            echo "wp-config-db-password-fix: watching $CONF"
            while true; do
              if [[ -f "$CONF" ]] && grep -q "define( 'DB_PASSWORD'" "$CONF" && ! grep -qF "$MARKER" "$CONF"; then
                echo "wp-config-db-password-fix: patching literal DB_PASSWORD -> dynamic secret read"
                cp "$CONF" "$CONF.bak-$(date +%s)"
                chmod u+w "$CONF"
                sed -i "s#define( 'DB_PASSWORD',.*#define( 'DB_PASSWORD', trim( file_get_contents( '/secrets/mariadb-password' ) ) );#" "$CONF"
                chmod 444 "$CONF"
                echo "wp-config-db-password-fix: patched"
              fi
              sleep 60
            done

    # In-cluster Memcached (Bitnami sub-chart) replaces the managed
    # ElastiCache service -- cost optimization, see issue #32. When
    # enabled, the chart auto-wires WORDPRESS's cache host/port to this
    # service and externalCache.* is ignored.
    memcached:
      enabled: true
      architecture: standalone
      resourcesPreset: nano

    wordpressConfigureCache: true

    # The Bitnami image blocks /xmlrpc.php by default (Apache <Files> deny
    # rule, re-rendered from this env var on every container start). Jetpack
    # and some third-party integrations rely on XML-RPC and otherwise see a
    # 403/404 from the "Jetpack Connection" health check. Pingback methods
    # remain disabled separately regardless of this setting (see
    # wordpress_disable_pingback in the Bitnami entrypoint), so this does not
    # re-expose the pingback DDoS vector -- only the rest of the XML-RPC API.
    extraEnvVars:
      - name: WORDPRESS_ENABLE_XML_RPC
        value: "yes"
  YAML
}
