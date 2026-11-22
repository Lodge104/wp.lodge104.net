ingress:
  annotations:
    alb.ingress.kubernetes.io/certificate-arn: "${acm_certificate_arn}"
    alb.ingress.kubernetes.io/security-groups: "${alb_security_group_id}"
    alb.ingress.kubernetes.io/manage-backend-security-group-rules: "true"
    alb.ingress.kubernetes.io/load-balancer-attributes: "idle_timeout.timeout_seconds=120,routing.http2.enabled=true"
    alb.ingress.kubernetes.io/target-group-attributes: "stickiness.enabled=true,stickiness.lb_cookie.duration_seconds=86400,load_balancing.algorithm.type=least_outstanding_requests"
  # CloudFront forwards the viewer Host header for dynamic Multisite
  # behaviors, but some cache behaviors (for example static assets)
  # still use the origin domain as Host, so the ALB needs a matching
  # rule for origin.${env_domain}.
  extraHosts:
    - name: origin.${env_domain}
      path: /
    # Multisite "store" site, routed to this same release/ingress.
    # pathType must be explicit: extraHosts defaults to ImplementationSpecific,
    # which ALB treats as an exact "/" match instead of a prefix, so only the
    # homepage would route and every asset path would fail.
    - name: store.${env_domain}
      path: /
      pathType: Prefix
%{ if root_domain_ingress_hosts }    # Root-domain aliases are accepted by prod CloudFront and route to
    # this release; wp-config redirects www to the canonical apex.
    - name: ${domain}
      path: /
      pathType: Prefix
    - name: www.${domain}
      path: /
      pathType: Prefix
    - name: store.${domain}
      path: /
      pathType: Prefix
%{ endif ~}
