---
name: chameleon-cloud
description: Use when managing Chameleon Cloud resources - creating leases, reservations, launching bare metal instances, managing networks, floating IPs, ccauth/cc-login authentication, or any openstack/blazar CLI operations on CHI@UC or CHI@TACC
---

# Chameleon Cloud Management

Manage bare metal reservations and instances on Chameleon Cloud (CHI@UC or CHI@TACC) via CLI.

**JSON parsing:** use `-f json` on blazar/openstack output and pipe it through `jq`. The operator hosts ship `jq` only; `jaq` is not installed.

## CLI Wrapper

All commands use the `chi` wrapper script at `scripts/chi.sh` relative to this skill's base directory.

Authentication goes through Chameleon's [`ccauth`](https://chameleoncloud.readthedocs.io/en/latest/technical/cli/ccauth.html) OIDC device flow (browser approval, no password). The wrapper runs `blazar` (`chameleon-blazarclient`) and `openstack` (`python-openstackclient`) with ccauth's keystoneauth plugin.

**Before running any commands:**
1. Ask the user which site: **UC** (`CHI@UC`) or **TACC** (`CHI@TACC`).
2. Set the site and wrapper path: `export CHI_SITE="uc"` (or `"tacc"`) and `CHI="<skill-base-dir>/scripts/chi.sh"` (use the absolute path from the skill's base directory).
3. Log in: run `$CHI login` **as a background task** (`run_in_background`). It reuses the cached refresh token and exits at once when that is still valid. Otherwise it prints `To authenticate please go to: <url>` and polls until the user approves. Read that URL from the task output, give it to the user, and wait for the task to finish before running anything else.

Then run commands as:
```bash
$CHI blazar <args...>
$CHI openstack <args...>
```

**IMPORTANT:** Prefix every `blazar` and `openstack` command below with `$CHI`. All scripts go through `chi.sh`, so `CHI_SITE` (default `uc`) selects the site for them too.

### Auth details

- The refresh token is cached at `~/.cache/ccauth/refresh_token.json` (override the directory with `CC_LOGIN_STATE`). It comes from Chameleon's single Keycloak realm, so **one login covers both sites** — switching `CHI_SITE` needs no new login.
- `$CHI blazar` / `$CHI openstack` refuse to run when no token is cached. A cached but *expired* token still makes them block on a device flow whose URL you cannot see, which is why step 3 runs `$CHI login` first.
- `$CHI logout` clears the cached token.
- **`cc-login`** (same package) trades the device login for a portable, **unrestricted** OpenStack application credential (default lifetime 24h), for contexts without `ccauth` installed. It can create further non-expiring credentials as the user if leaked, so only generate one when asked and never commit the output:
  ```bash
  $CHI cc-login --output-openrc <file>          # export OS_AUTH_TYPE=v3applicationcredential ...
  $CHI cc-login --output-clouds-yaml <file>     # entry named `chameleon` (--cloud-name to change)
  $CHI cc-login --force-refresh --output-openrc <file>   # bypass the cached credential
  ```
  The wrapper adds the site flags and a per-site credential cache; don't pass them.
- **On a Chameleon instance**, CC-* images ship `ccauth` and `cc-login` on `cc`'s `PATH`, and they discover site and project from the metadata service. Instance vendordata no longer carries credentials: `~/openrc` is not populated at boot and `cc-generate-openrc` is gone. If the user needs OpenStack credentials *on a node* (e.g. `sudo -E cc-snapshot <image>` or `setup-cc-mount-object-store`), run there: `ccauth openrc --output ~/openrc && source ~/openrc`.

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

Run the availability script (two API calls, ~10 s):

```bash
<skill-base-dir>/scripts/check-availability.sh
```

It prints, per node type: total, free, reserved and unreservable counts, plus the first release time among the reserved hosts.

### Step 3: Prompt the User

Ask:
1. **Lease name?**
2. **Which node type?** (Skylake or Cascade Lake)
3. **How many nodes?**
4. **Duration?**
5. **SSH keypair?** (`$CHI openstack keypair list -f json | jq -r '.[].Name'`)
6. **OS image?** (e.g. CC-Ubuntu22.04, CC-Ubuntu24.04)

If requested count exceeds free nodes, show earliest time when enough become free.

### Step 4: Create the Lease

Run the lease creation script. It creates a `physical:host` lease starting now and polls until ACTIVE (timeout 120s).

```bash
<skill-base-dir>/scripts/create-lease.sh <name> <node-type> <count> "<end-date>"
```

`<end-date>` is UTC (`YYYY-MM-DD HH:MM`). No floating IP is reserved; Step 6 reuses the site's pre-existing IP.

### Step 5: Launch Instances

Use the batch launch script. It launches in batches of 2 (system concurrency limit) and polls until each batch is ACTIVE before continuing.

```bash
<skill-base-dir>/scripts/launch-instances.sh <lease-name> <image> <keypair> <count>
```

Instances are named `<lease-name>-1`, `<lease-name>-2`, etc. These names do not identify a lease; see [Instances belonging to a lease](#instances-belonging-to-a-lease). Bare metal takes ~10-15 min per batch.

Run it with `run_in_background` and wait for its exit notification; it polls and exits on its own. Do not watch its output with `tail -F`, which never exits.

### Step 6: Attach Floating IP

After instances are ACTIVE, run the attach script. It attaches the site's pre-existing floating IP to `<lease-name>-1` (bastion host pattern).

| Site | Floating IP |
|------|-------------|
| CHI@UC | `192.5.87.43` |
| CHI@TACC | `129.114.108.129` |

```bash
<skill-base-dir>/scripts/attach-floating-ips.sh <lease-name>
```

The script detaches the IP from any previous server before attaching. If it fails with `No FloatingIP found`, the IP was reclaimed from the project; Neutron policy forbids requesting a specific address. Ask the user, then allocate a new one with `$CHI openstack floating ip create public` and update this table, `attach-floating-ips.sh`, and the `uc`/`tacc` host in `modules/home-manager/common/ssh.nix`.

SSH access:
- **Bastion (first node):** `ssh cc@<floating-ip>`
- **Other nodes:** `ssh -J cc@<floating-ip> cc@<private-ip>`

### Step 7: Post-Instance Setup

After the floating IP is attached and SSH is working, use the setup script. For the bastion node, pass the floating IP directly. For other nodes, pass their private IPs with `SSH_JUMP` set to the bastion:

```bash
# Bastion (first node)
<skill-base-dir>/scripts/setup-instance.sh <floating-ip>

# Other nodes (via SSH jump), one background task per IP
SSH_JUMP=cc@<floating-ip> <skill-base-dir>/scripts/setup-instance.sh <private-ip>
```

After stale host key removal, it runs these steps per instance, in order:
- `rclone`: copy the GDrive and Box OAuth tokens (best-effort; requires `/run/agenix/rclone-{gdrive,box}-token` on the operator host).
- `terminfo`: install the Ghostty terminfo.
- `apt`: apt update/upgrade, then install uidmap/podman.
- `userns`: apply the AppArmor unprivileged-userns fix (required for rootless podman).
- `linger`: `loginctl enable-linger cc`, for persistent user services.
- `nix`: install Nix.

Set `STEPS` to run a subset, e.g. `STEPS=nix` when the user wants Nix but not their config. Run instances in parallel as background tasks.

### Ordering note

On a fresh chameleon node, run `setup-instance.sh` **before** the first `home-manager switch --flake github:jiezhuzzz/nice#chameleon`. The provisioning script writes `~/.local/share/rclone/{gdrive,box}-token`, which the rclone home-manager module reads at activation. If `home-manager switch` runs first on a node without the tokens, `rclone-config.service` fails and the `rclone-mount:@{gdrive,box}.service` units do not start. Recovery after dropping the tokens in:

```bash
systemctl --user start rclone-config.service
systemctl --user start 'rclone-mount:@gdrive.service' 'rclone-mount:@box.service'
```

## Quick Reference

| Task | Command |
|------|---------|
| List hosts (with node_type) | `$CHI blazar host-list --long` |
| Show host details | `$CHI blazar host-show <id>` |
| List allocations | `$CHI blazar allocation-list host` |
| Create lease | `$CHI blazar lease-create --reservation "..." --end-date "..." <name>` |
| Show lease | `$CHI blazar lease-show <name>` |
| List leases | `$CHI blazar lease-list` |
| Extend lease | `$CHI blazar lease-update --prolong-for "1d" <name>` |
| Delete lease | `$CHI blazar lease-delete <name>` |
| List servers | `$CHI openstack server list` |
| List a lease's instances | `<skill-base-dir>/scripts/lease-instances.sh <lease-name>` |
| Delete server | `$CHI openstack server delete <name>` |
| List keypairs | `$CHI openstack keypair list` |
| List networks | `$CHI openstack network list` |
| List images | `$CHI openstack image list` |

## Instances belonging to a lease

To count or list the instances running under a lease, **map by reservation, not by name.** Instance names (`<lease>-N`) are labels chosen at launch and do not encode lease membership — the per-lease counter can run on, and names can even appear swapped between leases (e.g. a `Laurel-eval` lease whose instances are named `Laurel-dev`). Matching by name prefix gives wrong counts.

Use the helper script, which resolves it reliably:

```bash
<skill-base-dir>/scripts/lease-instances.sh <lease-name>
```

It prints the reserved-host count and every instance scheduled on those hosts, mapping `lease → host reservation id(s) → Blazar host id(s) → hypervisor_hostname(s) → server`.

The mapping chain, if you need to do it by hand:

1. `blazar lease-show <name> -f json` → `.reservations` (host reservation id, `resource_type == "physical:host"`).
2. `blazar allocation-list host -f json` → the `resource_id`s (Blazar host ids) whose `.reservations[].id` matches.
3. `blazar host-list -f json` → map each Blazar host id to its `hypervisor_hostname`.
4. `openstack server list --long -f json` → the server whose `.Host` equals that `hypervisor_hostname` is the instance on that reserved node.

> `.reservations` is a JSON array in both `lease-show` and `allocation-list` under the pinned `chameleon-blazarclient`; index it directly (`.reservations[]`).

## Extend a Lease

Duration suffixes: `w` (weeks), `d` (days), `h` (hours).

```bash
$CHI blazar lease-update --prolong-for "2d" my-lease
```

## Common Mistakes

- **Counting/identifying a lease's instances by name prefix** -- see [Instances belonging to a lease](#instances-belonging-to-a-lease); use `lease-instances.sh`.
- Confusing **lease ID** with **reservation ID** -- extract with `jq` from `lease-show`
- Forgetting `--hint reservation=<id>` for `server create`
- Using `--flavor` other than `baremetal` for physical hosts
- Using `$CHI openstack reservation ...` -- the wrapper's `openstack` env has no blazarclient plugin, and the scripts depend on the `blazar` CLI's output shapes; use `$CHI blazar`
- Asking the user for a password or exporting `OS_PASSWORD` -- auth is `ccauth`'s device flow; run `$CHI login`
- Running the `blazar` shell against a hand-made or `ccauth openrc`-generated env without `OS_ACCESS_TOKEN_TYPE=access_token` -- its argparse auth loading hands the plugin `None`, the refresh silently fails, and the command blocks on a device flow despite a valid cached login. `chi.sh` sets it.
