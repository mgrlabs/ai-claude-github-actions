# CLAUDE.md

## Project Overview

Azure Terraform module for deploying an active-active Palo Alto VM-Series firewall pair behind internal load balancers. Uses the PaloAltoNetworks/swfw-modules community module and references an existing virtual network with management, public, and private subnets.

## Project Structure

```
azure/
  main.tf         — Data sources, firewall module, load balancers
  variables.tf    — Input variable definitions
  locals.tf       — Local values (firewall map, etc.)
  outputs.tf      — Module outputs
  providers.tf    — Provider and version constraints
  tests/test.tf   — Terraform test configuration
```

## Terraform Best Practice Scanning

When writing or reviewing Terraform code in this repository, **always** validate against the following best practices. Flag any violations and fix them before considering work complete.

### Security

- Never hardcode secrets, passwords, or API keys in `.tf` files — use variables marked `sensitive = true` or a secrets manager
- Ensure `admin_password` and similar credentials are sourced from variables with `sensitive = true`, never from defaults
- Do not expose management interfaces to the public internet — verify `create_public_ip = false` on management NICs
- Use `Standard` SKU for load balancers (not `Basic`) to get zone-redundancy and NSG support
- Verify health probes use appropriate protocols (HTTPS preferred over HTTP/TCP where possible)

### Code Quality

- Pin provider versions with constraint operators (`~>`) — never use unconstrained providers
- Pin module versions — never reference a module `source` without a `version` constraint
- All variables must have a `description` and an appropriate `type` constraint
- All variables with restricted values should use `validation` blocks
- Use `locals` to reduce repetition — do not duplicate expressions across resources
- Outputs must include `description` fields

### Naming and Tagging

- All resources must follow the naming convention: `${var.client_prefix}-<resource-purpose>`
- All resources that support `tags` must include tags — at minimum: `environment`, `managed_by = "terraform"`, and `project`
- Resource group names must be parameterised, not hardcoded

### State and Backend

- A `backend` block should be configured for remote state (e.g., `azurerm` backend with a storage account) — local state is only acceptable for development/testing
- State files (`*.tfstate`, `*.tfstate.backup`) must never be committed to version control

### Structural Rules

- One resource type per file where practical; shared data sources may live in `main.tf` or a dedicated `data.tf`
- Use `for_each` over `count` for resources that represent distinct objects
- Keep `providers.tf` separate from resource definitions
- Place tests under a `tests/` directory using Terraform's native test framework

### Validation Commands

Before approving any Terraform change, run (or confirm the CI pipeline runs):

```sh
terraform fmt -check -recursive   # Formatting
terraform validate                # Syntax and internal consistency
terraform plan                    # Review planned changes — no unexpected destroys
```

Where available, also run static analysis:

```sh
tflint                            # Linting and provider-specific rules
tfsec                             # Security scanning
checkov -d .                      # Policy-as-code checks (CIS, SOC2, etc.)
```

### Review Checklist

When modifying or reviewing Terraform in this repo, check:

- [ ] No secrets or credentials in plain text
- [ ] Provider and module versions are pinned
- [ ] All variables have `description`, `type`, and `validation` where appropriate
- [ ] All resources are tagged per the tagging standard
- [ ] Naming convention is followed
- [ ] `terraform fmt` produces no diff
- [ ] `terraform validate` passes
- [ ] No `*.tfstate` files in version control
- [ ] Changes do not introduce unexpected resource destruction
- [ ] Load balancer health probes use the most secure protocol available
- [ ] Management interfaces are not publicly exposed
