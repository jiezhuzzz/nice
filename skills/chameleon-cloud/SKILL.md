---
name: chameleon-cloud
description: Use when managing Chameleon Cloud resources - creating leases, reservations, launching bare metal instances, managing networks, floating IPs, or any openstack/blazar CLI operations on CHI@UC or CHI@TACC
---

# Chameleon Cloud Management

Manage bare metal reservations and instances on Chameleon Cloud (CHI@UC or CHI@TACC) via CLI.
**Assume `jaq` is installed.** Use `-f json` with blazar/openstack and pipe through `jaq` to extract fields.

## CLI Wrapper

All commands use the `chi` wrapper script at `scripts/chi.sh` relative to this skill's base directory.

**Before running any commands:**
1. Ask the user which site: **UC** (`CHI@UC`) or **TACC** (`CHI@TACC`).
2. Ask the user for `OS_PASSWORD` interactively. Never store or hardcode it.
3. Export both: `export OS_PASSWORD="<password>" CHI_SITE="uc"` (or `"tacc"`)
4. Set the wrapper path: `CHI="<skill-base-dir>/scripts/chi.sh"` (use the absolute path from the skill's base directory)

Then run commands as:
```bash
$CHI blazar <args...>
$CHI openstack <args...>
```

**IMPORTANT:** Prefix all `blazar` and `openstack` commands below with `$CHI`. Combine `export OS_PASSWORD`, `CHI_SITE`, and `CHI=` with each command using inline env vars or a single export block at the start of the session. The `CHI_SITE` env var selects the site (`uc` or `tacc`, defaults to `uc`).

## Supported Node Types

**CHI@UC:**

| Label | node_type value |
|-------|-----------------|
| Skylake | `compute_skylake` |
| Cascade Lake | `compute_cascadelake_r` |

**CHI@TACC:**

| Label | node_type value |
|-------|-----------------|
| Skylake | `compute_skylake` |
| Cascade Lake | `compute_cascadelake` |
| Cascade Lake R | `compute_cascadelake_r` |

## Reservation Workflow (MUST FOLLOW)

When the user asks to reserve hosts, follow **all steps** in order.

### Steps 1-2: Check Availability

Run the availability script to query all hosts, allocations, and node types, then display a summary:

```bash
<skill-base-dir>/scripts/check-availability.sh
```

Requires `OS_PASSWORD` env var. Outputs a node availability summary automatically (free/reserved counts per type, next availability dates).

### Step 3: Prompt the User

Ask:
1. **Lease name?**
2. **Which node type?** (Skylake or Cascade Lake)
3. **How many nodes?**
4. **Duration?**
5. **SSH keypair?** (`$CHI openstack keypair list -f json | jaq -r '.[].Name'`)
6. **OS image?** (e.g. CC-Ubuntu22.04, CC-Ubuntu24.04)

If requested count exceeds free nodes, show earliest time when enough become free.

### Step 4: Create the Lease

Run the lease creation script. It gets the public network ID, creates the lease with host + floating IP reservations, and polls until ACTIVE (timeout 120s).

```bash
<skill-base-dir>/scripts/create-lease.sh <name> <node-type> <count> "<end-date>"
```

Requires `OS_PASSWORD` env var. Omits `--start-date` to start immediately. No floating IP reservation — a pre-existing IP is reused.

### Step 5: Launch Instances

Use the batch launch script. It launches in batches of 2 (system concurrency limit) and polls until each batch is ACTIVE before continuing.

```bash
<skill-base-dir>/scripts/launch-instances.sh <lease-name> <image> <keypair> <count>
```

Requires `OS_PASSWORD` env var. Instances are named `<lease-name>-1`, `<lease-name>-2`, etc. Bare metal takes ~10-15 min per batch.

### Step 6: Attach Floating IP

After instances are ACTIVE, run the attach script. It attaches the site's pre-existing floating IP to `<lease-name>-1` (bastion host pattern).

| Site | Floating IP |
|------|-------------|
| CHI@UC | `192.5.87.161` |
| CHI@TACC | `129.114.108.248` |

```bash
<skill-base-dir>/scripts/attach-floating-ips.sh <lease-name>
```

Requires `OS_PASSWORD` and `CHI_SITE` env vars. The script detaches the IP from any previous server before attaching.

SSH access:
- **Bastion (first node):** `ssh cc@<floating-ip>`
- **Other nodes:** `ssh -J cc@<floating-ip> cc@<private-ip>`

### Step 7: Post-Instance Setup

After the floating IP is attached and SSH is working, use the setup script. For the bastion node, pass the floating IP directly. For other nodes, pass their private IPs with `SSH_JUMP` set to the bastion:

```bash
# Bastion (first node)
<skill-base-dir>/scripts/setup-instance.sh <floating-ip>

# Other nodes (via SSH jump)
SSH_JUMP=cc@<floating-ip> <skill-base-dir>/scripts/setup-instance.sh <private-ip1> <private-ip2> ...
```

This script handles per-instance: stale host key removal, env/op-token copy, Ghostty terminfo, apt update/upgrade, uidmap install, AppArmor unprivileged userns fix (required for rootless podman), and Nix install. Run instances in parallel as background tasks.

## Quick Reference

| Task | Command |
|------|---------|
| List hosts | `$CHI blazar host-list` |
| Show host details | `$CHI blazar host-show <id>` |
| List allocations | `$CHI blazar allocation-list host` |
| Create lease | `$CHI blazar lease-create --reservation "..." --end-date "..." <name>` |
| Show lease | `$CHI blazar lease-show <name>` |
| List leases | `$CHI blazar lease-list` |
| Extend lease | `$CHI blazar lease-update --prolong-for "1d" <name>` |
| Delete lease | `$CHI blazar lease-delete <name>` |
| List servers | `$CHI openstack server list` |
| Delete server | `$CHI openstack server delete <name>` |
| List keypairs | `$CHI openstack keypair list` |
| List networks | `$CHI openstack network list` |
| List images | `$CHI openstack image list` |

## Extend a Lease

Duration suffixes: `w` (weeks), `d` (days), `h` (hours).

```bash
$CHI blazar lease-update --prolong-for "2d" my-lease
```

## Common Mistakes

- Confusing **lease ID** with **reservation ID** -- extract with `jaq` from `lease-show`
- Forgetting `--hint reservation=<id>` for `server create`
- Using wrong floating IPs -- always filter by `reservation:<id>` tag
- Using `--flavor` other than `baremetal` for physical hosts
- Using `openstack reservation` commands -- they don't exist; use `blazar` CLI
