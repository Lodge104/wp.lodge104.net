# RDS for MySQL

- **Docs**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html
- **Docs (llms.txt)**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/llms.txt
- **Data model**: Relational (community MySQL)
- **Query language**: MySQL SQL (identical to community)
- **Compatibility**: IS community MySQL (not "compatible" — it IS MySQL)
- **Serverless**: No (fixed instance types)
- **Scale to zero**: No
- **VPC required**: Yes
- **Multi-region**: Cross-region read replicas (async)
- **Free Tier**: Accounts opened after July 15, 2025 use the six-month, $200 credit-based Free Plan; eligible legacy accounts may have service-specific 12-month offers. Verify current RDS MySQL eligibility in the account's Free Tier plan
- **Min cost**: $0 (free tier) → ~$15/month after
- **Time to first query**: 10-15 min (VPC + instance + configuration)
- **Key features**: All MySQL features, reserved instances (up to 60% off), full portability, Multi-AZ deployments
- **Limitations**: No auto-scaling compute, manual instance sizing, no serverless option
- **Best for**: Cost-sensitive MySQL workloads, portability priority, teams wanting standard MySQL with no proprietary layer
- **Not for**: Variable traffic needing auto-scaling (Aurora MySQL is better), new apps without MySQL requirement
