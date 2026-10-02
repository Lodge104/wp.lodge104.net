# Aurora MySQL

- **Docs**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraMySQL.html
- **Docs (llms.txt)**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/llms.txt
- **Data model**: Relational (MySQL-compatible)
- **Query language**: MySQL SQL
- **Compatibility**: MySQL-compatible; feature support varies by Aurora engine version, so validate compatibility before migrating
- **Serverless**: Yes
- **Serverless type**: Capacity — you still create and manage a cluster, but compute scales automatically (including to zero with auto-pause)
- **Scale to zero**: Yes, via auto-pause
- **VPC required**: Yes (no Express Configuration for MySQL)
- **Multi-region**: Global Database for disaster recovery
- **Free Tier**: Accounts opened after July 15, 2025 use the six-month, $200 credit-based Free Plan; eligible legacy accounts may have service-specific 12-month offers. Eligible Aurora MySQL usage can consume account credits; verify current account and service eligibility
- **Min cost**: ~$0 with auto-pause; ~$45/month always-on at 0.5 ACU (compute only; storage billed separately)
- **Time to first query**: 10-15 min (VPC + cluster setup)
- **Key features**: Serverless, Global Database, I/O-Optimized, parallel query
- **Migration tooling**: Aurora MySQL power for Kiro (AI-assisted RDS MySQL → Aurora MySQL migration via the Kiro IDE; a migration aid, not an engine feature)
- **Limitations**: No Express Configuration, no pgvector equivalent
- **Best for**: Existing MySQL workloads, teams with MySQL expertise
- **Not for**: New apps without MySQL requirement
