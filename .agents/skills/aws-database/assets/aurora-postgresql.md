# Aurora PostgreSQL

- **Docs**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/Aurora.AuroraPostgreSQL.html
- **Docs (llms.txt)**: https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/llms.txt
- **Data model**: Relational (PostgreSQL-compatible)
- **Query language**: PostgreSQL SQL (full dialect + extensions)
- **Compatibility**: PostgreSQL-compatible; extension and FDW support varies by Aurora engine version, so check AWS's supported list
- **Serverless**: Yes (Serverless, auto-scaling 0-256 ACU)
- **Serverless type**: Capacity — you still create and manage a cluster, but compute scales automatically (including to zero with auto-pause)
- **Scale to zero**: Yes, via auto-pause
- **VPC required**: Yes (unless Express Configuration — no VPC, PostgreSQL only, limited regions)
- **Multi-region**: Global Database for disaster recovery (<1s replication, single write region)
- **Free Tier**: Accounts opened after July 15, 2025 use the six-month, $200 credit-based Free Plan; eligible legacy accounts may have service-specific 12-month offers. Check current Aurora PostgreSQL plan limits and service eligibility before relying on Free Plan capacity
- **Min cost**: ~$0 with auto-pause (storage only); ~$45/month always-on at 0.5 ACU (compute only; storage billed separately)
- **Time to first query**: ~90-120 seconds (Express Configuration) or 10-15 min (standard VPC setup)
- **Key features**: Express Configuration, I/O-Optimized, Managed Upgrades with Blue/Green Deployments, AWS Organizations for upgrade rollout policy, supported PostgreSQL extensions such as pgvector and PostGIS (availability varies by engine version), dynamic data masking (pg_columnmask), Zero ETL integrations to Redshift and Opensearch, up to 5x write and 3x read throughput vs RDS, faster failover (<30s vs 60-120s for RDS Multi-AZ)
- **Limitations**: Single write region, slightly higher cost than RDS for equivalent instance size, proprietary storage layer (not portable to community PostgreSQL without application-level export)
- **Best for**: Workloads requiring a PostgreSQL-compatible engine with validated extension support, pgvector/AI embeddings where supported, migrations from PostgreSQL, refactors from Oracle/SQL Server
- **Not for**: Users who just need simple SQL without PG-specific features (DSQL is simpler)
