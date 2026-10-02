# RDS for PostgreSQL

- **Docs**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_PostgreSQL.html
- **Docs (llms.txt)**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/llms.txt
- **Data model**: Relational (community PostgreSQL)
- **Query language**: PostgreSQL SQL (identical to community)
- **Compatibility**: IS community PostgreSQL (not "compatible" — it IS PostgreSQL)
- **Serverless**: No (fixed instance types)
- **Scale to zero**: No
- **VPC required**: Yes
- **Multi-region**: Cross-region read replicas (async)
- **Free Tier**: Accounts opened after July 15, 2025 use the six-month, $200 credit-based Free Plan; eligible legacy accounts may have service-specific 12-month offers. Verify current RDS PostgreSQL eligibility in the account's Free Tier plan
- **Min cost**: $0 (free tier) → ~$15/month after
- **Time to first query**: 10-15 min (VPC + instance + configuration)
- **Key features**: PostgreSQL extensions including pgvector and PostGIS, Managed Upgrades with Blue/Green Deployments, AWS Organizations for upgrade rollout policy, High availability and disaster recovery options such as Multi-AZ instances, delayed read replicas, Zero ETL integrations to Redshift
- **Limitations**: Manual instance sizing, no serverless, slower failover than Aurora
- **Best for**: Cost-sensitive workloads, teams wanting standard community PostgreSQL with full portability
- **Not for**: Variable traffic workloads needing auto-scaling
