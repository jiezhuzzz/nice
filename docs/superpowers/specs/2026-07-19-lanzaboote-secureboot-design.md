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
    autoGenerateKeys.enable = true;
    autoEnrollKeys.enable = true; # includeMicrosoftKeys defaults to true
  };

  # TPM2 unlock requires the systemd-based initrd
  boot.initrd.systemd.enable = true;

  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["tpm2-device=auto"];

  environment.systemPackages = [pkgs.sbctl];
}
```

Plus a comment block documenting the BIOS setup-mode step, since that is not expressible in Nix.

**Version pin: `lanzaboote` v1.1.0** — the latest release, verified to contain `autoGenerateKeys`, `autoEnrollKeys`, and `measuredBoot`.

**`pkiBundle` resolved:** `/var/lib/sbctl` is correct. This is the value v1.1.0's own `docs/getting-started/prepare-your-system.md:71` prescribes, and the module derives `${pkiBundle}/keys/db/db.{pem,key}` from it (`nix/modules/lanzaboote.nix:123,130`), matching sbctl 0.18's layout. The older `/etc/secureboot` seen in other configs is superseded. The option has **no default** — it must be set explicitly.

### Key material

Signing keys are **unmanaged host-local state** at `/var/lib/sbctl`, generated declaratively by Lanzaboote's `generate-sb-keys` systemd unit (`autoGenerateKeys.enable`), which runs `sbctl create-keys` guarded by `ConditionPathExists = "!/var/lib/sbctl/keys"` so it fires exactly once. They never enter the flake. Nothing irreplaceable is lost if the disk dies — the unit regenerates them and the firmware is re-enrolled.

Enrollment is likewise declarative (`autoEnrollKeys.enable`): a `prepare-sb-auto-enroll` unit writes `PK.auth`/`KEK.auth`/`db.auth` to `${esp}/loader/keys/auto/`, and **systemd-boot performs the actual firmware enrollment on the next boot** — which only works while the firmware is in setup mode. `includeMicrosoftKeys` is left at its default `true`, retaining the vendor keys the Dell's option ROMs may need. `autoReboot` is deliberately left `false` so the reboot into enrollment is a conscious act.

Rejected: encrypting the keys into agenix. Lanzaboote needs them during the same activation in which agenix would decrypt them, creating an ordering problem, and the only payoff is skipping the BIOS dance on a full reinstall.

### TPM2 sealing policy

Seal to **PCR 7 only** (Secure Boot state). PCR 7 changes only when Secure Boot keys or state change, so kernel upgrades and new NixOS generations do not break unlock.

Rejected: PCR 0+7, which additionally binds firmware measurements — any Dell BIOS update would silently break unlock and force manual re-enrollment. Rejected: a TPM PIN, which would defeat the passphrase-less goal.

Accepted trade-off: with PCR 7 alone, anyone who powers on the laptop reaches the login screen with the disk already unlocked. The defense is the user password, not the disk. This is a deliberate choice, not an oversight.

**Considered and deferred: `boot.lanzaboote.measuredBoot`.** v1.1.0 supports `systemd-pcrlock`, which binds PCRs 0/4/7 and regenerates its policy on every `nixos-rebuild` — solving exactly the BIOS-update brittleness that made us reject a static PCR 0+7. It was deferred because systemd still marks pcrlock experimental, and Lanzaboote's own guide recommends `--tpm2-with-pin=true` for attended workstations, which would give up the passphrase-less goal. Revisit once plain Secure Boot has proven stable on this machine. (Our `configurationLimit = 5` is within pcrlock's maximum of 8, so no blocker there.)

## Rollout

Ordering is load-bearing. PCR 7 measures Secure Boot state, so TPM enrollment must come **last** — enrolling earlier seals against a PCR value that is about to change, and unlock then fails silently on the next boot.

1. **systemd initrd alone** — `boot.initrd.systemd.enable = true`, rebuild, reboot, confirm the LUKS passphrase prompt still works. No Secure Boot involvement yet.
2. Add the `lanzaboote` input and the module with `enable`, `pkiBundle`, and `autoGenerateKeys` — but **not** `autoEnrollKeys`. Rebuild. The `generate-sb-keys` unit creates `/var/lib/sbctl`, and generations are now signed.
3. `sudo sbctl verify` — confirm every EFI file is signed **before** touching firmware
4. BIOS → Secure Boot → Custom mode → *Delete All Secure Boot Variables* (setup mode)
5. Enable `autoEnrollKeys.enable = true`, rebuild, reboot — systemd-boot enrolls the keys during that boot
6. `bootctl status` → confirm `Secure Boot: enabled (user)`; enable Secure Boot in BIOS if the firmware left it off
7. **Reboot again before sealing.** This step is not optional and is easy to miss. PCR 7 is measured by firmware early in boot and then frozen for that boot. In the boot where systemd-boot performs enrolment, firmware has *already* measured PCR 7 against the pre-enrolment state — so `sbctl status` will correctly report `Secure Boot: enabled` (it reads EFI variables, which did change) while PCR 7 still holds the old value. Sealing there binds a stale measurement, and the next boot fails with `TPM policy does not match current system state`. A reboot forces firmware to re-measure PCR 7 against the enrolled state.
8. **Only now:** `sudo systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 /dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9`
9. Reboot; confirm passphrase-less unlock, then test the fallback by declining the TPM

**Outcome (2026-07-19): implemented and verified.** Secure Boot reports `enabled (deployed)` — enrolling a PK from Audit Mode transitions this Dell straight to Deployed Mode, so re-enrolment requires the BIOS key-clear path rather than anything from the OS. `--firmware-builtin` successfully restored `builtin-db`/`builtin-KEK`. TPM unlock cut the initrd from 14.6s to 4.3s with zero policy-mismatch errors, and PCR 7 proved stable across reboots.

The PCR 7 timing trap in step 7 was hit during implementation, exactly as described: sealing happened in the enrolment boot, and the following boot failed with `TPM policy does not match current system state`. The fix was re-sealing with `--wipe-slot=tpm2` once the system had rebooted into its steady state. Note `systemd-cryptenroll` refuses to re-enrol an identical PCR set ("This PCR set is already enrolled, executing no operation"), so changing an existing enrolment means wiping first.

Splitting `autoGenerateKeys` (step 2) from `autoEnrollKeys` (step 5) is deliberate: it puts `sbctl verify` between key creation and any firmware modification, so signing is proven correct while the machine is still trivially recoverable.

### Commit staging

Four commits, each with its own reboot checkpoint, so a failure identifies its own cause:

1. systemd initrd alone
2. Lanzaboote signing + key generation
3. Auto-enrollment (the only firmware-modifying step)
4. TPM2 crypttab option

Enrollment and TPM sealing are separate commits rather than one, because they fail in different ways and each needs its own reboot to prove out.

## Risks

- ~~**`boot.initrd.systemd.enable = true` is the riskiest line.**~~ **Retracted 2026-07-19 after verification.** nixpkgs 26.11 defaults this option to `true` (`nixos/modules/system/boot/systemd/initrd.nix:196`), nothing in this repo overrides it, and `systemd-analyze` on the running `nixps` already reports an initrd phase. The machine is *already* on the systemd initrd, so there is no initrd swap and no associated reboot risk. The option is still set explicitly, as a deliberate pin: TPM2 unlock depends on it, and a future nixpkgs default flip would otherwise break unlock silently.
- **Old generations become unbootable once Secure Boot is on.** Generations built before Lanzaboote are unsigned, so the boot-menu rollback escape hatch does not cover them.
- **Corrected 2026-07-19: the installer USB is not a rescue path under Secure Boot.** Lanzaboote's `docs/explanation/troubleshooting.md:52` states the NixOS install medium is unsigned and therefore cannot boot while Secure Boot is active. Earlier drafts of this spec listed it as a recovery option alongside disabling Secure Boot; that was wrong. **Disabling Secure Boot in firmware is the primary recovery mechanism**, and the USB is only usable after doing so. This raises the importance of confirming the BIOS exposes *Restore Factory Keys* before enrollment.
- **`sbctl enroll-keys` in setup mode is the hardest step to undo.** Clearing factory keys is reversible via "Restore Factory Keys" on most MSI/Dell firmware; confirm this machine's BIOS exposes it before step 5.

## Verification

CI cannot meaningfully test this — `nix flake check` and `nixos-rebuild build` only prove it evaluates. Real verification is on-device and manual:

- `sbctl verify` — all EFI files signed
- `bootctl status` — `Secure Boot: enabled (user)`
- `cryptsetup luksDump` — TPM2 token present
- Actual reboots at steps 3, 7, and 10
- Fallback test: decline the TPM, confirm the passphrase still unlocks
