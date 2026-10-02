# RDS for MariaDB

- **Docs**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MariaDB.html
- **Docs (llms.txt)**: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/llms.txt
- **Data model**: Relational (community MariaDB)
- **Query language**: MariaDB SQL (MySQL-compatible with extensions)
- **Compatibility**: MariaDB (10.6, 10.11), MySQL-compatible but diverging (new features like system-versioned tables, Oracle-mode PL/SQL)
- **Serverless**: No (fixed instance types)
- **Scale to zero**: No
- **VPC required**: Yes
- **Multi-region**: Cross-region read replicas (async)
- **Free Tier**: Accounts opened after July 15, 2025 use the six-month, $200 credit-based Free Plan; eligible legacy accounts may have service-specific 12-month offers. Verify current RDS MariaDB eligibility in the account's Free Tier plan
- **Min cost**: $0 (free tier) → ~$15/month after
- **Time to first query**: 10-15 min (VPC + instance + configuration)
- **Key features**: System-versioned (temporal) tables, Oracle PL/SQL compatibility mode, Aria storage engine, reserved instances (up to 60% off), full portability
- **Limitations**: No auto-scaling compute, no serverless, smaller managed-tooling footprint than MySQL/PostgreSQL on AWS, no Aurora equivalent
- **Best for**: MariaDB migrations, teams using MariaDB-specific features (temporal tables, Oracle mode), open-source MySQL alternative without Oracle ownership
- **Not for**: Variable traffic needing auto-scaling, new apps without MariaDB requirement (Aurora MySQL or Aurora PostgreSQL are better starting points)
