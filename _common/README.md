# `_common/` – shared Terragrunt configuration

Every stack under `dev/`, `test/`, `prod/` and `global/` is a **thin shim**.
All logic lives here, so a routine change means editing **one file** in this
folder, and that change applies to every env at once.

```hcl
# <env>/<region>/<stack>/terragrunt.hcl  (or global/<stack>/terragrunt.hcl)
include "root" {
  path = find_in_parent_folders("root.hcl")     # remote state + provider
}

include "common" {
  path = "${get_repo_root()}/_common/<stack>.hcl" # source, deps, inputs
}

inputs = {}                                      # real one-off overrides only
```

## Layout

| Path | What it is |
|---|---|
| `../root.hcl` | Remote state (S3 key = stack path) and the generated `aws` provider. |
| `../project.hcl` | Project constants: `project_name`, `domain`, `parent_zone_id`. |
| `../<env>/env.hcl` | **Env-level knobs** (sizing, flags). Only values that differ from the `_common` defaults. |
| `../<env>/<region>/region.hcl` | `aws_region`, `alb_hosted_zone_id`. |
| `_env.hcl` | Helper that resolves the current stack's env/region/project context (see below). |
| `<stack>.hcl` | Full fragment for one stack: `terraform { source }`, `dependency` blocks with mocks, `locals`, `inputs`. |
| `route53-zone.hcl` | Shared by `global/route53-{dev,test,prod,wp}`; the zone name comes from the folder name. |
| `shared/*.hcl` | Plain `locals` that **other** stacks need to read (see "Shared values"). |
| `wordpress/` | Helm values for the WordPress release (`base.yaml` + `*.yaml.tpl` templates). |
| `mock-ca.pem` | Public self-signed dummy CA (`CN=mock`, no private key) used in EKS dependency mocks. Explicitly un-ignored in `.gitignore`. |

## How to change X

| I want to… | Edit |
|---|---|
| Change a value for **one env** (sizing, a flag) | `<env>/env.hcl` – see the knob list below. |
| Change a default / module input for **all envs** | `_common/<stack>.hcl` |
| Bump a module version | `terraform { source }` in `_common/<stack>.hcl` |
| Add/change a dependency or its mock outputs | `dependency` blocks in `_common/<stack>.hcl` |
| Change the Kubernetes version (EKS + bastion kubectl) | `_common/shared/eks.hcl` |
| Change the DB name / master user | `_common/shared/rds.hcl` (also hard-coded in `_modules/env-promotion/files/ssm-promote.sh`) |
| Change the WordPress chart version / release name | `_common/shared/wordpress.hcl` |
| Change WordPress Helm values for all envs | `_common/wordpress/base.yaml` |
| Change per-env WordPress Helm values | `_common/wordpress/env-values.yaml.tpl` (+ a knob in `env.hcl`) |
| Change ALB ingress annotations / hosts | `_common/wordpress/ingress.yaml.tpl` |
| Change the CloudFront cache behaviours | `_common/cloudfront.hcl` (`locals`) |
| Change remote state / the provider block | `../root.hcl` |
| Add a one-off override for a single stack | `inputs = { … }` in that stack's shim (shallow-merged over the fragment's inputs) |
| Add a new stack | `scripts/new-stack.sh <stack> <module-source> [env …]` |

## Env-level knobs (`<env>/env.hcl`)

Required in every env: `env`, `vpc_cidr`, `eks_node_groups`, `rds_instances`,
`rds_scaling`, and a `wordpress = { … }` map with `blog_name`,
`replica_count`, `resources_preset`, `persistence_size`, `pdb_create` and
`pod_anti_affinity_preset`.

Optional (default in brackets):

| Knob | Used by | Default |
|---|---|---|
| `is_prod` | everything via `_env.hcl` | `env == "prod"` |
| `serves_root_domain` | acm, cdn, cloudfront, wordpress – apex `<domain>`, `www.`, `store.`, `cdn.` | `false` |
| `eks_cluster_autoscaler_tags` | eks | `true` |
| `rds_deletion_protection` | rds | `is_prod` |
| `rds_final_snapshot` | rds | `is_prod` |
| `rds_backup_retention_period` | rds | `30` in prod, `7` otherwise |
| `rds_destroy_snapshot_hook` | rds – destroy-time `extra_arguments` | `true` |
| `cdn_force_destroy` | cdn | `!is_prod` |
| `cdn_origin_access_control_name` | cdn – `null` = module default `"cdn"` | `"cdn-<env>"` |
| `cloudfront_origin_read_timeout` | cloudfront | `60` |
| `cloudfront_access_logs` | cloudfront – needs a `cloudfront-logs` stack in that env | `false` |
| `wordpress.hpa_enabled` | wordpress | `true` |
| `wordpress.hpa_max_replicas` | wordpress | `10` in prod, `2` otherwise |
| `wordpress.pdb_min_available` | wordpress | `1` |
| `wordpress.resource_limits` | wordpress – explicit requests/limits | `true` |
| `wordpress.skip_install` | wordpress – `wordpressSkipInstall`; `null` omits it | `is_prod` |
| `wordpress.www_redirect` | wordpress – `www.<domain>` → `<domain>` 301 | `true` |
| `wordpress.root_domain_ingress_hosts` | wordpress – apex hosts on the ingress | `true` |
| `wordpress.wellknown_hook` | wordpress – `.well-known` postStart hook | `true` |
| `wordpress.helm_timeout` | wordpress – `null` = module default | `900` |
| `wordpress.admin_secret_recovery_window_in_days` | wordpress – `null` = module default (0) | `7` |

Inside a fragment, read optional knobs with a default so `env.hcl` only lists
real differences:

```hcl
locals {
  ctx     = read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals
  timeout = try(local.ctx.env_vars.cloudfront_origin_read_timeout, 60)
}
```

## `_env.hcl` exports

`read_terragrunt_config("${get_repo_root()}/_common/_env.hcl").locals` returns:

| Local | Example (dev) |
|---|---|
| `env` | `dev` (`global` for `global/` stacks) |
| `region` | `us-east-1` |
| `project` / `domain` | `net-lodge104-wp` / `lodge104.net` |
| `name` | `net-lodge104-wp-dev` – canonical resource-name prefix |
| `env_domain` | `dev.wp.lodge104.net` (`null` in `global/`) |
| `is_prod`, `serves_root_domain` | flags, see knobs above |
| `parent_zone_id`, `alb_hosted_zone_id` | from `project.hcl` / `region.hcl` |
| `env_vars`, `region_vars`, `project_vars` | raw `locals` of `env.hcl` / `region.hcl` / `project.hcl` |
| `stack_name`, `stack_path`, `is_global` | e.g. `vpc`, `dev/us-east-1/vpc`, `false` |
| `mock_outputs_allowed_terraform_commands` | `["init", "validate", "plan", "destroy"]` |

## Gotchas (Terragrunt v1.1.6)

- **Use `include` for fragments, `read_terragrunt_config` for helpers.** In a
  file loaded with `read_terragrunt_config()`, `find_in_parent_folders()` and
  `get_terragrunt_dir()` resolve from `_common/`, not from the stack. That's
  why `_env.hcl` walks up from `get_original_terragrunt_dir()`.
  `scripts/verify-env-helper.sh` checks this.
- **`include` is single-level.** A fragment can't `include` another file;
  read helpers with `read_terragrunt_config()` instead.
- **Fragments with `dependency` blocks can't be read from another stack.**
  `read_terragrunt_config()` tries to resolve the dependencies relative to
  the reader and fails. Put values other stacks need in `shared/<x>.hcl`.
- **`locals` are evaluated before dependencies.** Anything that uses
  `dependency.*.outputs` has to be written in `inputs` (or `generate`), not
  in `locals`.
- **Relative `config_path` resolves from the stack.** `config_path = "../vpc"`
  in a fragment points at the sibling stack of whichever env includes it.
- **No `dynamic` blocks inside `terraform {}`.** To switch an
  `extra_arguments` block off, set `commands = []` (see `rds.hcl`).
- **`null` inputs are passed through explicitly.** To fall back to a module
  default, leave the key out with a conditional `merge()` instead of setting
  it to `null` (see `cdn.hcl`, `wordpress.hcl`).
- **Optional dependencies:** `dependency { enabled = false }` keeps the
  dependency out of the run graph and resolves to its mocks (see the `logs`
  dependency in `cloudfront.hcl`).
- **Helm `values` lists are merged like repeated `-f` files.** For any
  top-level key, the last block that sets it wins wholesale; lists aren't
  concatenated. Keep every entry for a key (e.g. `extraVolumes`) in the same
  template.
- **`_modules/env-promotion/files/ssm-promote.sh` is embedded in a deployed
  SSM document.** Any edit to it, comments included, changes that resource
  on the next apply.

## Checking a change is a no-op

```bash
scripts/render-snapshot.sh /tmp/before        # on the base branch
# ...make the change...
scripts/render-snapshot.sh /tmp/after
diff -r /tmp/before /tmp/after                 # empty diff == same config
scripts/lint-shims.sh                          # shims stay thin
terragrunt hcl fmt --check
```

`render-snapshot.sh` renders every stack offline (dependency outputs are not
fetched, so no AWS access is needed) and masks render-time timestamps. Finish
with a read-only `terragrunt plan -lock=false` on the affected test/prod
stacks.
