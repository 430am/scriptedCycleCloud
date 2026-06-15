# scriptedCycleCloud

Terraform that stands up the Azure infrastructure for a single-VM Azure
CycleCloud server (Ubuntu 24.04 by default, marketplace or SIG image), with a
modular layout. Inspired by [430am/cyclecloud_as_code][src] but split into
discrete child modules, swapping cloud-init for two `azurerm_virtual_machine_run_command`
phases (install, register), with hooks for optional storage and a Compute
Gallery in follow-up passes.

[src]: https://github.com/430am/cyclecloud_as_code

> **Scope**: lab / developer environment. Single region, single VM, no HA. Not
> production-hardened — see the `ponytail:` comments in code for the known
> simplifications and their upgrade paths.

## Layout

```
infra/
├── terraform.tf            # providers + commented azurerm backend
├── variables.tf            # root inputs
├── locals.tf               # naming token, tag merging, operator-IP detection
├── main.tf                 # composition: module calls + subscription-scope RBAC
├── outputs.tf
├── environments/
│   ├── dev.example.tfvars
│   └── prod.example.tfvars
├── tests/
│   └── plan.tftest.hcl     # plan-only smoke test
└── modules/
    ├── network/            # VNet + subnets + NSGs + NAT GW + Bastion + private DNS zones
    ├── identity/           # Key Vault (RBAC, PE) + UAI + SSH key + secrets + diag
    ├── monitoring/         # LA workspace + monitoring SA + AMPLS + PEs + diag
    ├── storage_locker/     # CycleCloud locker SA + container + PE + diag
    └── cyclecloud_server/  # VM + NIC + Run Commands (install, register) + VM-scoped RBAC
scripts/
├── install-cyclecloud.sh.tftpl    # Phase 1: OpenJDK, az CLI, cyclecloud8
└── register-cyclecloud.sh.tftpl   # Phase 2: account_data.json + cyclecloud initialize / account create
.github/workflows/
├── ci.yml                  # fmt + validate + tflint on PRs
└── security.yml            # tfsec + checkov + trivy on PRs
.tflint.hcl
.pre-commit-config.yaml
```

## What the v1 deployment includes

| Resource                  | Module             | Notes                                                                                          |
| ------------------------- | ------------------ | ---------------------------------------------------------------------------------------------- |
| VNet (`10.150.0.0/16`)    | `network`          | 4 subnets via `cidrsubnet`. `AzureBastionSubnet` only created when `access_mode = "bastion"`.  |
| NAT Gateway               | `network`          | Attached to `cluster` + `server` subnets for deterministic outbound.                           |
| Bastion (Standard, tunnel)| `network`          | Only when `access_mode = "bastion"`.                                                           |
| Private DNS zones (x7)    | `network`          | KV + storage (blob, table) + AMPLS set, VNet-linked.                                            |
| Key Vault (RBAC)          | `identity`         | Firewall default-Deny + operator IP allow-list; PE for in-VNet access.                          |
| User-assigned identity    | `identity`         | Attached to the VM; reserved for future cluster nodes.                                          |
| SSH key + admin password  | `identity`         | Ephemeral-ish (regular `tls_private_key` for now — see `ponytail:` note).                       |
| Log Analytics workspace   | `monitoring`       | SMI-enabled; linked to AMPLS via scoped service.                                                |
| Monitoring SA + PEs       | `monitoring`       | Public network disabled, keys disabled, OAuth-only. Blob + table PEs.                          |
| AMPLS + PE                | `monitoring`       | Private ingestion; query stays Open (see `ponytail:` note).                                     |
| Locker SA + container     | `storage_locker`   | LRS, RBAC-only, container created via AAD auth (provider `storage_use_azuread = true`).        |
| CycleCloud server VM      | `cyclecloud_server`| Ubuntu 24.04 by default; encrypted-at-host; SMI + UAI; Azure Monitor Linux Agent extension.    |
| Run Commands x2           | `cyclecloud_server`| Phase 1 install, Phase 2 register. Re-edits to the script trigger re-runs.                     |
| Custom subscription role  | root `main.tf`     | "CycleCloud Orchestrator" assigned to both the VM SMI and the UAI at subscription scope.       |

### Optional (deferred to a follow-up pass)
- Premium Files NFSv4.1 (`sched`, `shared`).
- Azure NetApp Files (capacity pool + volumes).
- Azure Managed Lustre (scratch).
- General-purpose data SA / ADLSv2.
- Azure Compute Gallery + operator-defined image definitions.
- Third `access_mode = "app_gateway"` (App Gateway + optional WAF + Bastion side-by-side).

## Prerequisites

- Terraform `>= 1.11.0` (uses azurerm 4.x features).
- Azure CLI, logged in (`az login`).
- Subscription role: **Owner** is the simplest (custom role definition + role
  assignments at subscription scope require both `Microsoft.Authorization/roleDefinitions/write`
  and `roleAssignments/write`).
- `export ARM_SUBSCRIPTION_ID=<your-subscription-id>` — read by the `azurerm`
  provider; **not** hardcoded in `terraform.tf`.

## Quickstart

```bash
cd infra
cp environments/dev.example.tfvars environments/dev.tfvars   # gitignored; edit allowed_ip_addresses if you want public_ip mode

export ARM_SUBSCRIPTION_ID=<your-subscription-id>
az login

terraform init
terraform plan  -var-file=environments/dev.tfvars
terraform apply -var-file=environments/dev.tfvars
```

The two Run Commands surface their stdout via `terraform apply` output and the
portal (VM → Run command). On script edits, re-running `apply` updates the
`source.script` value which triggers a fresh execution of that phase only.

## Access modes

| Mode        | What you get                                                                          |
| ----------- | ------------------------------------------------------------------------------------- |
| `bastion`   | Azure Bastion (Standard, tunneling enabled). No public IP on the VM. Default.         |
| `public_ip` | Public IP attached to the VM NIC, NSG allow-rule scoped to `allowed_ip_addresses`.    |

The operator's source IP is auto-detected via `https://api.ipify.org` and added
to both the Key Vault firewall and (in `public_ip` mode) the NSG allow-list.

## Server image

Pass `var.server_image` to switch between marketplace and Shared Image Gallery:

```hcl
# Marketplace (default)
server_image = {
  source = "marketplace"
  marketplace = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

# Shared Image Gallery
server_image = {
  source                        = "shared_image_gallery"
  shared_image_gallery_image_id = "/subscriptions/.../galleries/.../images/<def>/versions/<ver>"
}
```

## Tooling

```bash
pip install pre-commit
pre-commit install                  # runs fmt + validate + tflint + trivy on commit
pre-commit run --all-files

cd infra
terraform fmt -recursive
terraform validate
terraform test                      # plan-only; needs Azure auth so the provider initializes
```

## State backend

The `azurerm` backend block in [infra/terraform.tf](infra/terraform.tf) is
commented out. To migrate from local state to a remote backend:

1. Create an SA + container out-of-band (or via a separate bootstrap module).
2. Uncomment the `backend "azurerm" {}` block and fill in values.
3. `terraform init -migrate-state`.

## Layout decisions (the why)

- **Modules are pure** (no cross-module data lookups); root wires outputs into
  inputs. Exception: `cyclecloud_server` holds the VM-SMI → Key Vault / locker
  RBAC because the register Run Command needs to depend on a single
  `time_sleep` gating RBAC propagation.
- **Hand-rolled modules, no AVM**: fewer files, no transitive deps.
- **Run Commands over cloud-init**: idempotent, observable (output in state +
  portal), re-runs on script edits without rebuilding the VM.
- **Provider `storage_use_azuread = true`**: lets us create the locker
  container against a key-disabled storage account using AAD auth.
