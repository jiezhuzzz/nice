# Lanzaboote Secure Boot + TPM2 LUKS unlock on `nixps`

**Date:** 2026-07-19
**Status:** Approved, not yet implemented
**Scope:** `nixps` only. `nixmachine` is explicitly out of scope.

## Goal

Boot `nixps` with UEFI Secure Boot using our own keys, via [Lanzaboote](https://github.com/nix-community/lanzaboote), and use the resulting signed boot chain to unlock the LUKS root from the TPM — so the machine boots to the login screen without a passphrase, with the existing passphrase retained as a fallback.

## Why only `nixps`

`hosts/nixos/` contains exactly two hosts. The macOS hosts and the standalone home-manager boxes (`chameleon`, `goku`, `vegeta`) have no NixOS bootloader, so Lanzaboote is irrelevant there.

`nixmachine` is technically a viable candidate — it is UEFI with `systemd-boot` and `canTouchEfiVariables = true` (`hosts/nixos/nixmachine/default.nix:39`) — but it is a headless homelab box with no LUKS root, so it gets none of the TPM2 payoff while carrying all of the "one bad enrollment means physical access" risk. It stays on plain `systemd-boot` unless a specific threat model appears.

## Current state

- `nixps` LUKS root: `cryptroot`, XFS, `/dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9` (`hosts/nixos/nixps/hardware.nix:26`)
- ESP at `/boot`, `FFC4-2547`
- `systemd-boot` comes from the shared `modules/nixos/boot.nix`, imported via `profiles/nixos-desktop.nix:10`
- `boot.plymouth.enable = true`; initrd is currently the **scripted** (non-systemd) implementation
- The repo defines **zero** custom `mkOption`/`mkEnableOption`; every module is a plain leaf composed by imports

## Design

### File layout

| File | Change |
|---|---|
| `flake.nix` | add `lanzaboote` input with `inputs.nixpkgs.follows = "nixpkgs"` |
| `modules/nixos/secureboot.nix` | **new** — the entire Secure Boot concern |
| `hosts/nixos/nixps/default.nix` | one line added to `imports` |
| `modules/nixos/boot.nix` | **untouched** |

`boot.nix` keeps `systemd-boot.enable = true`. `secureboot.nix` sets `lib.mkForce false`, which wins only on hosts that import it. `nixmachine` is unaffected because it never imports the module — no conditionals, no options, no new namespace. This follows the repo's existing plain-leaf-module convention.

### Module contents

```nix
{inputs, pkgs, lib, ...}: {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };

  # TPM2 unlock requires the systemd-based initrd
  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["tpm2-device=auto"];

  environment.systemPackages = [pkgs.sbctl];
}
```

Plus a comment block documenting the BIOS setup-mode steps and `sbctl` invocations, since none of that is expressible in Nix.

**Open detail to verify at implementation time:** `pkiBundle` is version-dependent. Older Lanzaboote/sbctl used `/etc/secureboot`; current sbctl defaults to `/var/lib/sbctl`. Confirm against the version actually pinned rather than copying either path on faith.

### Key material

Signing keys are **unmanaged host-local state**. `sbctl create-keys` generates them on `nixps`; they never enter the flake. Nothing irreplaceable is lost if the disk dies — setup mode plus regeneration recreates them.

Rejected: encrypting them into agenix. Lanzaboote needs the keys during the same activation in which agenix would decrypt them, creating an ordering problem, and the only payoff is skipping the BIOS dance on a full reinstall.

### TPM2 sealing policy

Seal to **PCR 7 only** (Secure Boot state). PCR 7 changes only when Secure Boot keys or state change, so kernel upgrades and new NixOS generations do not break unlock.

Rejected: PCR 0+7, which additionally binds firmware measurements — any Dell BIOS update would silently break unlock and force manual re-enrollment. Rejected: a TPM PIN, which would defeat the passphrase-less goal.

Accepted trade-off: with PCR 7 alone, anyone who powers on the laptop reaches the login screen with the disk already unlocked. The defense is the user password, not the disk. This is a deliberate choice, not an oversight.

## Rollout

Ordering is load-bearing. PCR 7 measures Secure Boot state, so TPM enrollment must come **last** — enrolling earlier seals against a PCR value that is about to change, and unlock then fails silently on the next boot.

1. Add the input + module; `nixos-rebuild build` (eval only, nothing installed)
2. `sudo sbctl create-keys`
3. `nixos-rebuild switch` — generations are now signed
4. `sudo sbctl verify` — confirm every EFI file is signed **before** touching firmware
5. BIOS → Secure Boot → Custom mode → *Delete All Secure Boot Variables* (setup mode)
6. `sudo sbctl enroll-keys --microsoft` — `--microsoft` retains vendor keys the Dell's option ROMs may need
7. Reboot; enable Secure Boot in BIOS
8. `bootctl status` → confirm `Secure Boot: enabled (user)`
9. **Only now:** `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9`
10. Reboot; confirm passphrase-less unlock, then test the fallback by declining the TPM

### Commit staging

Three commits, each with its own reboot checkpoint, so a failure identifies its own cause:

1. systemd initrd alone
2. Lanzaboote signing
3. TPM2 crypttab option

## Risks

- **`boot.initrd.systemd.enable = true` is the riskiest line**, not Lanzaboote. It swaps the entire initrd implementation on a LUKS-rooted machine. Plymouth handles the LUKS prompt differently under systemd initrd, so a cosmetic regression is likely and a functional one is possible. Land and reboot on this by itself first.
- **Old generations become unbootable once Secure Boot is on.** Generations built before Lanzaboote are unsigned, so the boot-menu rollback escape hatch does not cover them. Recovery is disabling Secure Boot in BIOS, or a NixOS installer USB — have one made before step 7.
- **`sbctl enroll-keys` in setup mode is the hardest step to undo.** Clearing factory keys is reversible via "Restore Factory Keys" on most MSI/Dell firmware; confirm this machine's BIOS exposes it before step 5.

## Verification

CI cannot meaningfully test this — `nix flake check` and `nixos-rebuild build` only prove it evaluates. Real verification is on-device and manual:

- `sbctl verify` — all EFI files signed
- `bootctl status` — `Secure Boot: enabled (user)`
- `cryptsetup luksDump` — TPM2 token present
- Actual reboots at steps 3, 7, and 10
- Fallback test: decline the TPM, confirm the passphrase still unlocks
