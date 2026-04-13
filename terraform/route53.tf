# ============================================================
# Route53 — lodge104.net (Z02518842QX1X2K88785A)
# ============================================================
# Import all records:
#   terraform import aws_route53_record.<label> Z02518842QX1X2K88785A_<name>_<TYPE>

data "aws_route53_zone" "lodge104_net" {
  zone_id = "Z02518842QX1X2K88785A"
}

resource "aws_route53_record" "lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "lodge104.net"
  type    = "A"
  alias {
    name                   = "dzwimni312yoe.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "lodge104_net_mx" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "lodge104.net"
  type    = "MX"
  ttl     = 300
  records = [
    "30 aspmx5.googlemail.com.",
    "30 aspmx4.googlemail.com.",
    "30 aspmx3.googlemail.com.",
    "30 aspmx2.googlemail.com.",
    "20 alt2.aspmx.l.google.com.",
    "20 alt1.aspmx.l.google.com.",
    "10 aspmx.l.google.com.",
  ]
}

resource "aws_route53_record" "lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "lodge104.net"
  type    = "TXT"
  ttl     = 1
  records = [
    "v=spf1 include:_spf.mailersend.net a mx include:_spf.mlsend.com ?all",
  ]
}

resource "aws_route53_record" "r_18b722702c220c2f793558fe4393c010_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_18b722702c220c2f793558fe4393c010.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_1fe297026b5767b0020009797b9c0b6f.bwfqbhlrkg.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "b84ed5fa5ea29c534cbfbcee73947147_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_b84ed5fa5ea29c534cbfbcee73947147.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "_44a03dd16a1e634c76557adf902cc37a.gskhnxswdw.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "dmarc_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_dmarc.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DMARC1; p=none;",
  ]
}

resource "aws_route53_record" "r_2j4hbducscn2n66g34gckc6k73zsewtw_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "2j4hbducscn2n66g34gckc6k73zsewtw._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1800
  records = [
    "2j4hbducscn2n66g34gckc6k73zsewtw.dkim.amazonses.com",
  ]
}

resource "aws_route53_record" "r_2wdltlumy4qwuruqby3d5d2wqcnd5pt2_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "2wdltlumy4qwuruqby3d5d2wqcnd5pt2._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "2wdltlumy4qwuruqby3d5d2wqcnd5pt2.dkim.amazonses.com.",
  ]
}

resource "aws_route53_record" "r_462_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "462._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "462.domainkey.u46242114.wl115.sendgrid.net",
  ]
}

resource "aws_route53_record" "r_4622_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "4622._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "4622.domainkey.u46242114.wl115.sendgrid.net",
  ]
}

resource "aws_route53_record" "r_5u3m4tr24blx5gyhordfmgewx4piyvcf_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "5u3m4tr24blx5gyhordfmgewx4piyvcf._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "5u3m4tr24blx5gyhordfmgewx4piyvcf.dkim.amazonses.com.",
  ]
}

resource "aws_route53_record" "cwm2ebgob3ibhtxuhnd7wuoehuerq66k_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "cwm2ebgob3ibhtxuhnd7wuoehuerq66k._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1800
  records = [
    "cwm2ebgob3ibhtxuhnd7wuoehuerq66k.dkim.amazonses.com",
  ]
}

resource "aws_route53_record" "g6gb3ze55m5dnmfvfcdt5jzier6ijvcf_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "g6gb3ze55m5dnmfvfcdt5jzier6ijvcf._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "g6gb3ze55m5dnmfvfcdt5jzier6ijvcf.dkim.amazonses.com.",
  ]
}

resource "aws_route53_record" "google_domainkey_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "google._domainkey.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DKIM1; k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDF6mQ1vXnPP6jb3iba8kA+0p1EPiXrR2P6vAN59fwQo4Ini6WlRJj6x50JER35tQsbMDVHANJKxfcAOma26FV353vyssLI3zWWUWrLtTupiO6T8dR8ilCM5k04S9NBGiW1HG7g5asBWIwLIHhAo4vvdvT4MqVWhfX1cSiQb6U31wIDAQAB",
  ]
}

resource "aws_route53_record" "litesrv_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "litesrv._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "litesrv._domainkey.mlsend.com",
  ]
}

resource "aws_route53_record" "mee2ut2pz7glecwq2goupdostih2my7t_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "mee2ut2pz7glecwq2goupdostih2my7t._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 1800
  records = [
    "mee2ut2pz7glecwq2goupdostih2my7t.dkim.amazonses.com",
  ]
}

resource "aws_route53_record" "ml_domainkey_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "ml._domainkey.lodge104.net"
  type    = "TXT"
  ttl     = 1
  records = [
    "k=rsa; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQC7RweFsp2OQfNMxco5LWW/6ZjzRxKkCIPJTN33qW8Bs1xhQtUhwALmpILvlyPTPEwhUcOduWl0TGkTUQhG4Er6PIWMRrH46b9cRYGKRZCE/SMBbABVbHGR8Iyz1Ny9WmA2vgE1ZmHDzw6MFRG4Sreu/Gs6tTomTMxLf2dv5rDg2QIDAQAB",
  ]
}

resource "aws_route53_record" "mlsend_domainkey_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "mlsend._domainkey.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=DKIM1;t=s;p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDAfylSDCAmz9PEItYMcuJ0ic/ODXoycqxOf4Jey1QJLc8v4vaEWTfSEhIi0BpgciZqynd8Sk5BLSG/uGnuB9o51HutDu1Y3oWN+nHArpwrIDuEY9s3aQ6S7jRWUp+zbJnrDPWWpow8S6tzGhGKY5haX+/D4WbawYkoRqf5IFHlqwIDAQAB",
  ]
}

resource "aws_route53_record" "mlsend2_domainkey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "mlsend2._domainkey.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "mlsend2._domainkey.mailersend.net",
  ]
}

resource "aws_route53_record" "github_challenge_lodge104_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_github-challenge-lodge104.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "414b8d8e73",
  ]
}

resource "aws_route53_record" "a_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "a.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "lsct.ashburn.us1.twilio.com",
  ]
}

resource "aws_route53_record" "aftership462_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "aftership462.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "u46242114.wl115.sendgrid.net",
  ]
}

resource "aws_route53_record" "aia_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "aia.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_252978de8aaa07ed2c5dc554194673cf_aia_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_252978de8aaa07ed2c5dc554194673cf.aia.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_41cde25a688d031de00e12384b459a6e.xgxxrgwpcb.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "analytics_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "analytics.lodge104.net"
  type    = "A"
  ttl     = 300
  records = [
    "34.231.181.173",
  ]
}

resource "aws_route53_record" "r_6f9ff5a6038afb3d178beb031de06425_analytics_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_6f9ff5a6038afb3d178beb031de06425.analytics.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_1f76a3ece72eb35dfa39bfff461b284c.dqxlbvzbzt.acm-validations.aws",
  ]
}

resource "aws_route53_record" "www_analytics_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.analytics.lodge104.net"
  type    = "A"
  ttl     = 300
  records = [
    "34.231.181.173",
  ]
}

resource "aws_route53_record" "r_2f095a02c888462c221db154e5b8abf7_www_analytics_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_2f095a02c888462c221db154e5b8abf7.www.analytics.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_bf3576ad399f734af5a42fd64e5e71e6.dqxlbvzbzt.acm-validations.aws",
  ]
}

resource "aws_route53_record" "api_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "api.lodge104.net"
  type    = "A"
  alias {
    name                   = "d2v44vpwvy75o3.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "at_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "at.lodge104.net"
  type    = "A"
  alias {
    name                   = "d3rr2ybf3tkygp.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_34972c91b58862d100a644084ff3084c_at_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_34972c91b58862d100a644084ff3084c.at.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_be8c77bd0c0ee0405c4461e5af41354c.xgxxrgwpcb.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "auth_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "auth.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "lodge104-cd-k9eqfnqmnti5ixak.edge.tenants.auth0.com",
  ]
}

resource "aws_route53_record" "calendar_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "calendar.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ghs.googlehosted.com.",
  ]
}

resource "aws_route53_record" "camping_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "camping.lodge104.net"
  type    = "A"
  alias {
    name                   = "dhhle064m903a.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "camporee_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "camporee.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "cdn_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "cdn.lodge104.net"
  type    = "A"
  alias {
    name                   = "d3bpedlu1qto17.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "conclave_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "conclave.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "dev_lodge104_net_ns" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "dev.lodge104.net"
  type    = "NS"
  ttl     = 300
  records = [
    "ns-1727.awsdns-23.co.uk.",
    "ns-2.awsdns-00.com.",
    "ns-1166.awsdns-17.org.",
    "ns-606.awsdns-11.net.",
  ]
}

resource "aws_route53_record" "r_05d21e66cfde9c1ed83a063ee07f1ba0_www_dev_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_05d21e66cfde9c1ed83a063ee07f1ba0.www.dev.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_afbfd8cf6955ccbe203d9c46a2aff863.xlfgrmvvlj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "docs_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "docs.lodge104.net"
  type    = "A"
  alias {
    name                   = "docs-lodge104-net.vr1hmsdd0mj10.us-east-1.cs.amazonlightsail.com"
    zone_id                = "Z06246771KYU0IRHI74W4"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "r_3c0e16ac1e28b1c1159b12c5c9f75e70_docs_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_3c0e16ac1e28b1c1159b12c5c9f75e70.docs.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_d0bf1a3d90fb501e19e0a3e2094258a3.xlfgrmvvlj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "drive_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "drive.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ghs.googlehosted.com.",
  ]
}

resource "aws_route53_record" "elections_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "elections.lodge104.net"
  type    = "A"
  alias {
    name                   = "d35cmokzgc4f9g.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "emails_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "emails.lodge104.net"
  type    = "A"
  ttl     = 1
  records = [
    "35.198.93.67",
  ]
}

resource "aws_route53_record" "emails_lodge104_net_mx" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "emails.lodge104.net"
  type    = "MX"
  ttl     = 1
  records = [
    "10 mx.mlsrv.io.",
  ]
}

resource "aws_route53_record" "emails_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "emails.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 a mx include:_spf.mlsend.com ?all",
  ]
}

resource "aws_route53_record" "groups_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "groups.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ghs.googlehosted.com.",
  ]
}

resource "aws_route53_record" "guest_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "guest.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "guests_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "guests.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "insight_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "insight.lodge104.net"
  type    = "A"
  alias {
    name                   = "dualstack.lodge104-insight-lb-1610880812.us-east-1.elb.amazonaws.com"
    zone_id                = "Z35SXDOTRQ7X7K"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "link_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "link.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "links.mailersend.net",
  ]
}

resource "aws_route53_record" "list_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "list.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_546be5902806b8bcd9437de75b0f8d9c_login_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_546be5902806b8bcd9437de75b0f8d9c.login.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "_24b4c7ad840b43d1beea790e51319293.bxmgrlxjqk.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "mail_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "mail.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ghs.googlehosted.com.",
  ]
}

resource "aws_route53_record" "noac_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "noac.lodge104.net"
  type    = "A"
  alias {
    name                   = "dc6vth512oyrp.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_07782e4258b951bc581928c92d9914bd_noac_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_07782e4258b951bc581928c92d9914bd.noac.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_f24d3052c5fc9450ddb0ee83daa06e10.mhbtsbpdnt.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "www_noac_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.noac.lodge104.net"
  type    = "A"
  alias {
    name                   = "dc6vth512oyrp.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "ad023bfffda14465e161e068b441346c_www_noac_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_ad023bfffda14465e161e068b441346c.www.noac.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_4b3b1e0d0137f7cce02193f1194f94a4.mhbtsbpdnt.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "nominate_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "nominate.lodge104.net"
  type    = "A"
  alias {
    name                   = "d39jnywiritqy0.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "notify_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "notify.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "mailersend.net",
  ]
}

resource "aws_route53_record" "registration_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "registration.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "d2uaw82j99l2rj.cloudfront.net",
  ]
}

resource "aws_route53_record" "s_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "s.lodge104.net"
  type    = "A"
  alias {
    name                   = "d2yjahkh8l0kp0.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "s_lodge104_net_aaaa" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "s.lodge104.net"
  type    = "AAAA"
  alias {
    name                   = "d2yjahkh8l0kp0.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "send_lodge104_net_mx" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "send.lodge104.net"
  type    = "MX"
  ttl     = 300
  records = [
    "10 feedback-smtp.us-east-1.amazonses.com",
  ]
}

resource "aws_route53_record" "send_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "send.lodge104.net"
  type    = "TXT"
  ttl     = 1
  records = [
    "v=spf1 include:amazonses.com ~all",
  ]
}

resource "aws_route53_record" "ses_lodge104_net_mx" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "ses.lodge104.net"
  type    = "MX"
  ttl     = 1
  records = [
    "10 feedback-smtp.us-east-1.amazonses.com.",
  ]
}

resource "aws_route53_record" "ses_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "ses.lodge104.net"
  type    = "TXT"
  ttl     = 1
  records = [
    "v=spf1 include:amazonses.com ~all",
  ]
}

resource "aws_route53_record" "shop_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "shop.lodge104.net"
  type    = "A"
  alias {
    name                   = "s3-website-us-east-1.amazonaws.com"
    zone_id                = "Z3AQBSTGFYJSTF"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "slack_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "slack.lodge104.net"
  type    = "A"
  alias {
    name                   = "d3jbt7axoh112l.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "status_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "status.lodge104.net"
  type    = "A"
  alias {
    name                   = "dez21s1f71ddx.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "store_test_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "store-test.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "dzwimni312yoe.cloudfront.net",
  ]
}

resource "aws_route53_record" "r_1d48e72f9f8d7bf6dad9195e480e5e49_store_test_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_1d48e72f9f8d7bf6dad9195e480e5e49.store-test.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_086bd14fe8bf59785bb3e0ffd9bf8dd5.vrztfgqhxj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "www_store_test_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.store-test.lodge104.net"
  type    = "A"
  ttl     = 300
  records = [
    "44.209.203.111",
  ]
}

resource "aws_route53_record" "r_624728564fa3d65939ef0a0602a3d038_www_store_test_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_624728564fa3d65939ef0a0602a3d038.www.store-test.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_eb08f551069950142d81ce96045988c3.vrztfgqhxj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "store_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "store.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "dzwimni312yoe.cloudfront.net",
  ]
}

resource "aws_route53_record" "r_4b894f7da4e346b5d2a3b0be70c218f8_store_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_4b894f7da4e346b5d2a3b0be70c218f8.store.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_1ba3a4546c55cc50ab111d9049b034cd.bwfqbhlrkg.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "r_67f0fe49a3c3112a8d600c1073314129_store_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_67f0fe49a3c3112a8d600c1073314129.store.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "_d0e269ee6ba3c6f8d3b7e0757b65922e.bxmgrlxjqk.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "track_store_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "track.store.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "domains.aftership.com",
  ]
}

resource "aws_route53_record" "r_358d6dca6a6402fd778f39a968c430a1_www_store_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_358d6dca6a6402fd778f39a968c430a1.www.store.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_c861ee22846c291c6c191d8beded5e3e.vrztfgqhxj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "r_323862f438566bd1a869eeabdde14417_support_test_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_323862f438566bd1a869eeabdde14417.support-test.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_c3b0524dfa0beb19798df0956c0c04b5.bkngfjypgb.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "support_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "support.lodge104.net"
  type    = "A"
  alias {
    name                   = "d20qjikzgqcdex.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_7fa35945164cc2257d90e88ff9115ced_support_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_7fa35945164cc2257d90e88ff9115ced.support.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_38cf4e27f11ddb3a6d9f02ff91879adc.bkngfjypgb.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "test_support_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "test.support.lodge104.net"
  type    = "A"
  alias {
    name                   = "d1jl1zgniesbo3.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "f0781fe3f868e74479a721f384315834_test_support_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_f0781fe3f868e74479a721f384315834.test.support.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_3801adb64a1262ad22bf3de75d1b5bb3.tctzzymbbs.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "www_test_support_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.test.support.lodge104.net"
  type    = "A"
  alias {
    name                   = "d1jl1zgniesbo3.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_584362f50611ef56bf802fb1ca04a946_www_test_support_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_584362f50611ef56bf802fb1ca04a946.www.test.support.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_0b68e2a174ad9e95f4835e005e46a821.tctzzymbbs.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "www_support_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.support.lodge104.net"
  type    = "A"
  alias {
    name                   = "d20qjikzgqcdex.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_369b53d10487b2946668d051af98da21_www_support_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_369b53d10487b2946668d051af98da21.www.support.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_58c037d8217b985b514be416048c7b99.tctzzymbbs.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "r_6861cab444867bdb921fa677ef95a4e8_survey_test_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_6861cab444867bdb921fa677ef95a4e8.survey-test.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "_c99769b92b8a1ac48c111a8d7420eb8d.mntkzmhvxg.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "survey_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "survey.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "fd6096c48defb28a7cd1d2c1758c45a0_survey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_fd6096c48defb28a7cd1d2c1758c45a0.survey.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "_0463ea3d38684b96698dfe595a4c9b99.mntkzmhvxg.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "test_survey_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "test-survey.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ec2-3-93-59-23.compute-1.amazonaws.com.",
  ]
}

resource "aws_route53_record" "to_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "to.lodge104.net"
  type    = "A"
  ttl     = 1
  records = [
    "46.248.190.217",
  ]
}

resource "aws_route53_record" "track_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "track.lodge104.net"
  type    = "A"
  ttl     = 300
  records = [
    "34.91.249.129",
  ]
}

resource "aws_route53_record" "track_lodge104_net_mx" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "track.lodge104.net"
  type    = "MX"
  ttl     = 300
  records = [
    "10 mail.litesrv.io",
  ]
}

resource "aws_route53_record" "track_lodge104_net_txt" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "track.lodge104.net"
  type    = "TXT"
  ttl     = 300
  records = [
    "v=spf1 a mx include:_spf.mlsend.com ?all",
  ]
}

resource "aws_route53_record" "training_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "training.lodge104.net"
  type    = "A"
  alias {
    name                   = "d21ew56p6typso.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "r_60869dfc1361d86804b7cdb2c2d0b569_training_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_60869dfc1361d86804b7cdb2c2d0b569.training.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_e1f5156679f484ed3cfa9f14ef3261c8.zxwlrjxpwn.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "vo2vfg3bh7tz_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "vo2vfg3bh7tz.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "gv-xe2qvhggr4c77b.dv.googlehosted.com",
  ]
}

resource "aws_route53_record" "with_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "with.lodge104.net"
  type    = "CNAME"
  ttl     = 1
  records = [
    "ghs.googlehosted.com.",
  ]
}

resource "aws_route53_record" "wp_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "wp.lodge104.net"
  type    = "A"
  alias {
    name                   = "wp-lodge104-net.vr1hmsdd0mj10.us-east-1.cs.amazonlightsail.com"
    zone_id                = "Z06246771KYU0IRHI74W4"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "r_5f6f10323d924ffb942f0914bbcd08fb_wp_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_5f6f10323d924ffb942f0914bbcd08fb.wp.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_f77ae4280e6599cef19c5b584241b4d9.xlfgrmvvlj.acm-validations.aws.",
  ]
}

resource "aws_route53_record" "www_lodge104_net_a" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "www.lodge104.net"
  type    = "A"
  ttl     = 1
  records = [
    "44.209.203.111",
  ]
}

resource "aws_route53_record" "r_6f95b520c245c97d64cf3026843ac358_www_lodge104_net_cname" {
  zone_id = data.aws_route53_zone.lodge104_net.zone_id
  name    = "_6f95b520c245c97d64cf3026843ac358.www.lodge104.net"
  type    = "CNAME"
  ttl     = 300
  records = [
    "_1c525dda7a778d80b632116edd39ef46.bwfqbhlrkg.acm-validations.aws.",
  ]
}
