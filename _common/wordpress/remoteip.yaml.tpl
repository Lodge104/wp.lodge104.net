# The RDS password is mounted via the AWS Secrets Store CSI Driver
# (SecretProviderClass created by the helm-release module), which keeps
# ${rds_secret_name} in sync with Secrets
# Manager on rotation. Mounting the volume is what triggers the sync.
#
# apache-remoteip-conf: adds the mod_remoteip directives by
# replacing /opt/bitnami/apache/conf/deflate.conf (via the ConfigMap
# in extraDeploy below) with its original content plus our
# directives appended. Two things that look more obvious were tried
# and failed on 2026-10-29, so don't redo them:
#   1. The chart's top-level `apacheConfiguration` value REPLACES
#      the entire generated httpd.conf wholesale, including the MPM
#      module load line -- crashed every pod with "AH00534: httpd:
#      Configuration error: No MPM loaded".
#   2. subPath-mounting a NEW filename (e.g. zz-remoteip.conf) into
#      /opt/bitnami/apache/conf/vhosts/ -- which the default
#      httpd.conf auto-includes via `IncludeOptional
#      ".../vhosts/*.conf"` and looks like the obvious additive
#      injection point -- also crashed every pod
#      (FailedPostStartHook/CrashLoopBackOff). /opt/bitnami/apache/conf
#      is itself subPath-mounted into a shared empty-dir volume, and
#      vhosts/ doesn't exist yet on a fresh pod; subPath-mounting a
#      new file into a not-yet-existing nested directory makes
#      Kubernetes auto-create that directory root-owned (fsGroup
#      doesn't reliably apply here), so the entrypoint's own uid-1001
#      writes to every *sibling* file it refreshes there on every
#      boot (wordpress-vhost.conf, etc.) started failing with
#      "Permission denied".
# deflate.conf avoids both problems: it's a small, stable, named
# (non-wildcard) Include that sits at the TOP LEVEL of the already-
# established apache-conf-dir mount (same level as httpd.conf
# itself) -- no new directory needs to be created, so there's
# nothing for Kubernetes to get the ownership of wrong.
extraVolumes:
  - name: rds-secrets-store
    csi:
      driver: secrets-store.csi.k8s.io
      readOnly: true
      volumeAttributes:
        secretProviderClass: ${release_name}-rds
  - name: apache-remoteip-conf
    configMap:
      name: ${release_name}-remoteip-config

extraVolumeMounts:
  - name: rds-secrets-store
    mountPath: /mnt/secrets-store/rds
    readOnly: true
  - name: apache-remoteip-conf
    mountPath: /opt/bitnami/apache/conf/deflate.conf
    subPath: deflate.conf
    readOnly: true

# Without this, Apache/WordPress sees every request's client IP as
# one of CloudFront's/the ALB's own IPs instead of the real visitor,
# since CloudFront and the ALB are each a proxy hop in front of
# Apache. That breaks any IP-based security logic (e.g. Defender
# Security's Session Protection feature, which kills a session the
# moment the client IP appears to "change" between requests -- it
# was really just a different CloudFront/ALB IP every time, not the
# visitor -- confirmed live on 2026-10-29: every logged IP in
# Defender's lockout/audit logs fell inside AWS's published
# CLOUDFRONT_ORIGIN_FACING ranges). mod_remoteip resolves the real
# client IP from X-Forwarded-For and rewrites REMOTE_ADDR to match,
# once told which hops to trust.
extraDeploy:
  - |
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: ${release_name}-remoteip-config
      namespace: ${namespace}
    data:
      # Original /opt/bitnami/apache/conf/deflate.conf content
      # (captured live from the chart's default image on
      # 2026-10-29), unmodified, plus the RemoteIP directives
      # appended. If the bitnami/wordpress image's default
      # deflate.conf ever changes, re-sync this by hand.
      deflate.conf: |
        <IfModule mod_deflate.c>
          AddOutputFilterByType DEFLATE text/html text/plain text/xml text/css text/javascript
          AddOutputFilterByType DEFLATE application/x-javascript application/javascript application/ecmascript
          AddOutputFilterByType DEFLATE application/rss+xml
        </IfModule>
        LoadModule remoteip_module modules/mod_remoteip.so
        RemoteIPHeader X-Forwarded-For
${remoteip_trusted_proxies~}
