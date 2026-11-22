wordpressBlogName: "${blog_name}"
wordpressHost: ${wordpress_host}
%{ if skip_install != null }wordpressSkipInstall: ${skip_install}
%{ endif }
# Multisite (subdomain install): the network's primary domain stays
# ${env_domain}. Additional network sites (e.g. the
# store.* site) are added afterwards from wp-admin and can use any
# domain the proxy/ingress routes to this release -- they don't need
# to be literal subdomains of DOMAIN_CURRENT_SITE.
multisite:
  host: ${wordpress_host}

replicaCount: ${replica_count}
resourcesPreset: ${resources_preset}

externalDatabase:
  host: "${db_host}"
  port: 3306
  user: ${db_user}
  database: ${db_name}
  existingSecret: ${rds_secret_name}

# Cache is provided by the in-cluster Memcached sub-chart enabled in
# _common/wordpress.hcl (memcached.enabled: true) -- no external
# ElastiCache endpoint needed. See issue #32.

%{ if www_redirect }# NOTE: do not use '&&' (or any '&') in this block. The Bitnami image
# appends it into wp-config.php with sed, where '&' in the replacement
# expands to the matched text and corrupts the file (PHP parse error,
# wp core multisite-install exits 255, pod CrashLoopBackOffs on any
# fresh install). Prod only escapes it because its wp-config.php is
# already persisted (wordpressSkipInstall: true).
%{ endif }wordpressExtraConfigContent: |
%{ if www_redirect }  if (strcasecmp($_SERVER['HTTP_HOST'] ?? '', 'www.${domain}') === 0) {
    header('Location: https://${domain}' . ($_SERVER['REQUEST_URI'] ?? '/'), true, 301);
    exit;
  }
%{ endif }  define( 'WP_CACHE', true );
  define( 'AS3CF_SETTINGS', serialize( array(
      'provider' => 'aws',
      'use-server-roles' => true,
  ) ) );
  define( 'FLUENTMAIL_AWS_ACCESS_KEY_ID', '${ses_access_key_id}' );
  define( 'FLUENTMAIL_AWS_SECRET_ACCESS_KEY', '${ses_secret_access_key}' );

ingress:
  hostname: ${env_domain}

persistence:
  size: ${persistence_size}

podAntiAffinityPreset: ${pod_anti_affinity_preset}

autoscaling:
%{ if hpa_enabled }  enabled: true
  minReplicas: ${replica_count}
  maxReplicas: ${hpa_max_replicas}
  targetCPU: 60
  targetMemory: 75
%{ else }  enabled: false
%{ endif }
%{ if pdb_create }pdb:
  create: true
  minAvailable: ${pdb_min_available}
%{ else }# Cost savings: disable PDB in dev.
pdb:
  create: false
%{ endif }%{ if resource_limits }
# Bumped after the 2026-10-12 prod outage: the wordpress container was
# repeatedly OOMKilled at the old 1Gi limit (12-18 restarts/pod over a
# week), which left pods flapping between NotReady and crash-looping.
resources:
  requests:
    cpu: 250m
    memory: 768Mi
  limits:
    cpu: 1500m
    memory: 2Gi
%{ endif ~}
