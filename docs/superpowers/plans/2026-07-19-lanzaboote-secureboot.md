# Lanzaboote Secure Boot + TPM2 Unlock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Boot `nixps` with UEFI Secure Boot under our own keys via Lanzaboote, then seal the LUKS key to the TPM at PCR 7 so the machine unlocks without a passphrase.

**Architecture:** A single plain leaf module, `modules/nixos/secureboot.nix`, imported only by `hosts/nixos/nixps/default.nix`. It `mkForce`-disables the `systemd-boot` that `modules/nixos/boot.nix` enables, hands the bootloader to Lanzaboote, and switches the initrd to the systemd implementation that TPM2 unlock requires. `nixmachine` never imports it and is unaffected.

**Tech Stack:** NixOS (nixpkgs-unstable), lanzaboote v1.1.0, sbctl 0.18, systemd-boot, systemd-cryptenroll, TPM2.

**Spec:** `docs/superpowers/specs/2026-07-19-lanzaboote-secureboot-design.md`

## ⚠️ This Plan Is Not Agent-Executable End-to-End

Read this before starting. It is unlike a normal implementation plan:

- **There are no unit tests, and this plan contains no test code.** Bootloader configuration has no meaningful unit-test surface — `nix flake check` and `nixos-rebuild build` prove only that the config *evaluates*. Every real verification here is an on-device command or a physical reboot. Do not fabricate tests to satisfy a TDD habit; the verification steps are the tests.
- **Steps marked 🧑 HUMAN require physical presence** at the machine — BIOS menus, reboots, watching a boot succeed or fail. An agent cannot do these and must stop and hand off.
- **Task 3 modifies firmware state and is the hardest step to undo.** Do not begin it without the recovery media from Task 0.
- **Each task ends at a reboot checkpoint.** Do not batch tasks. If a reboot fails, the previous task is the culprit.

## Global Constraints

- Target host is **`nixps` only**. Never add these imports to `profiles/nixos-desktop.nix`, `modules/nixos/boot.nix`, or any `nixmachine` file.
- LUKS device UUID: `567ccf9f-ee66-4985-aa2c-e9850a0198e9` (device name `cryptroot`)
- ESP UUID: `FFC4-2547`, mounted at `/boot`
- `pkiBundle` is exactly `/var/lib/sbctl`. The option has no default and must be set.
- Lanzaboote pinned to **`v1.1.0`**, with `inputs.nixpkgs.follows = "nixpkgs"`.
- `includeMicrosoftKeys` stays at its default `true`. Never set `allowBrickingMyMachine`.
- Formatter is **alejandra** via `nix fmt`. Run it before every commit.
- Commits follow Conventional Commits with a required scope; use scope `secureboot`.
- The existing LUKS passphrase keyslot is never removed.

---

### Task 0: Recovery Preparation (🧑 HUMAN, do not skip)

**Files:** none — this task writes no code.

- [ ] **Step 1: Build a NixOS installer USB**

Any recent NixOS ISO on a USB stick.

> **Corrected 2026-07-19.** This step originally called the USB "the recovery path if Secure Boot rejects every generation." That is wrong: Lanzaboote's `troubleshooting.md:52` notes the NixOS install medium is unsigned and **cannot boot while Secure Boot is active**. The USB is only usable *after* disabling Secure Boot in firmware, which makes **BIOS access the primary recovery mechanism** and the USB secondary. Step 2 below is therefore the more important half of this task.

- [ ] **Step 2: Confirm the BIOS can restore factory keys**

Reboot into BIOS (`Del` on this Dell), navigate to Secure Boot → Key Management, and confirm a *Restore Factory Keys* entry exists. Do not activate it — just confirm it is there.

Expected: the entry exists. **If it does not, stop and reconsider the whole plan** — clearing keys would then be irreversible.

- [ ] **Step 3: Note the current boot generation**

Run: `nixos-rebuild list-generations | head -3`
Record the current generation number. You may need it to roll back.

---

### Task 1: Pin the systemd initrd explicitly

> **Revised 2026-07-19 during execution — this task is a no-op.** It was written as "the riskiest change in the plan," on the assumption that it swapped the initrd implementation. Verification showed otherwise: nixpkgs 26.11 already defaults `boot.initrd.systemd.enable` to `true` (`nixos/modules/system/boot/systemd/initrd.nix:196`), nothing in this repo overrides it, and `systemd-analyze` on the running `nixps` reports an initrd phase — so the machine is already there. The line is still worth setting, as an explicit pin of a prerequisite that TPM2 unlock depends on, but it changes no behavior. **Steps 5 and 6 below (the reboot checkpoint) are therefore unnecessary and were skipped.**

**Files:**
- Create: `modules/nixos/secureboot.nix`
- Modify: `hosts/nixos/nixps/default.nix` (imports list)

**Interfaces:**
- Produces: the module file that Tasks 2 and 3 extend, and its import line in the host.

- [ ] **Step 1: Create the module with only the initrd change**

Create `modules/nixos/secureboot.nix`:

```nix
# modules/nixos/secureboot.nix
# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
# Imported by hosts/nixos/nixps/default.nix only — nixmachine has no LUKS
# root and stays on plain systemd-boot.
_: {
  # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock.
  boot.initrd.systemd.enable = true;
}
```

- [ ] **Step 2: Import it from the host**

In `hosts/nixos/nixps/default.nix`, change the `imports` list to:

```nix
  imports = [
    ../../../profiles/nixos-desktop.nix
    ../../../modules/nixos/secureboot.nix
    ./hardware.nix
  ];
```

- [ ] **Step 3: Format and verify it evaluates**

Run: `nix fmt && nixos-rebuild build --flake .#nixps`
Expected: builds successfully, no eval errors. Nothing is installed yet.

- [ ] **Step 4: Commit**

```bash
git add modules/nixos/secureboot.nix hosts/nixos/nixps/default.nix
git commit -m "chore(secureboot): switch nixps to the systemd initrd

Prerequisite for TPM2-backed LUKS unlock. Shipped alone so a boot
regression from the initrd swap is unambiguous."
```

- [ ] **Step 5: 🧑 HUMAN — Activate and reboot**

Run: `sudo nixos-rebuild switch --flake .#nixps` then `reboot`

Expected: the machine boots, prompts for the LUKS passphrase, and reaches the desktop. The prompt may look different than before — that is acceptable. **If it does not boot, roll back at the boot menu to the generation from Task 0 Step 3 and stop.**

- [ ] **Step 6: 🧑 HUMAN — Confirm the systemd initrd is actually in use**

Run: `sudo journalctl -b 0 --no-pager | grep -i "systemd.*initrd\|Reached target Initrd"` and `bootctl status | head -20`
Expected: log lines showing initrd-phase systemd units ran. Do not proceed until confirmed.

---

### Task 2: Lanzaboote signing and key generation

Signs every generation and creates the keys — but does **not** touch firmware. `sbctl verify` at the end of this task proves signing works while the machine is still trivially recoverable.

**Files:**
- Modify: `flake.nix` (inputs)
- Modify: `modules/nixos/secureboot.nix`

**Interfaces:**
- Consumes: `boot.initrd.systemd.enable` from Task 1.
- Produces: `inputs.lanzaboote`; `/var/lib/sbctl` populated on-device; signed EFI files on the ESP.

- [ ] **Step 1: Add the flake input**

In `flake.nix`, after the `disko` block (line ~43), add:

```nix
    # Signed-boot (UEFI Secure Boot) for nixps. v1.1.0 provides
    # autoGenerateKeys/autoEnrollKeys; see modules/nixos/secureboot.nix.
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
```

- [ ] **Step 2: Extend the module**

Replace the entire contents of `modules/nixos/secureboot.nix` with:

```nix
# modules/nixos/secureboot.nix
# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
# Imported by hosts/nixos/nixps/default.nix only — nixmachine has no LUKS
# root and stays on plain systemd-boot.
#
# One-time firmware step, not expressible in Nix:
#   BIOS (Del) -> Settings -> Security -> Secure Boot -> Custom mode
#   -> Delete All Secure Boot Variables   (puts the firmware in setup mode)
# systemd-boot can only auto-enroll our keys while the firmware is in
# setup mode. `Restore Factory Keys` in the same menu is the way back.
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  # lanzaboote replaces systemd-boot, which modules/nixos/boot.nix enables.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    # sbctl 0.18's layout; lanzaboote reads ${pkiBundle}/keys/db/db.{pem,key}.
    pkiBundle = "/var/lib/sbctl";
    # `generate-sb-keys` runs `sbctl create-keys` once, guarded on the
    # absence of /var/lib/sbctl/keys.
    autoGenerateKeys.enable = true;
  };

  # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock.
  boot.initrd.systemd.enable = true;

  # For inspecting and verifying Secure Boot state.
  environment.systemPackages = [pkgs.sbctl];
}
```

- [ ] **Step 3: Format and verify it evaluates**

Run: `nix fmt && nixos-rebuild build --flake .#nixps`
Expected: builds successfully. If it errors that `pkiBundle` is missing a definition, the option was misspelled — it has no default and is required.

- [ ] **Step 4: Commit**

```bash
git add flake.nix flake.lock modules/nixos/secureboot.nix
git commit -m "feat(secureboot): sign nixps generations with lanzaboote

Pins lanzaboote v1.1.0 and enables signing plus one-shot key generation
at /var/lib/sbctl. Firmware is untouched until enrollment lands
separately, so signing can be verified while rollback is still trivial."
```

- [ ] **Step 5: 🧑 HUMAN — Activate**

Run: `sudo nixos-rebuild switch --flake .#nixps`
Expected: activation succeeds, and `generate-sb-keys.service` runs.

- [ ] **Step 6: 🧑 HUMAN — Confirm keys were generated**

Run: `sudo ls /var/lib/sbctl/keys/db/`
Expected: `db.pem` and `db.key` exist. If missing, check `systemctl status generate-sb-keys.service` before going further.

- [ ] **Step 7: 🧑 HUMAN — Verify every EFI file is signed (the critical gate)**

Run: `sudo sbctl verify`
Expected: every file under `/boot` reports as **signed**. Unsigned entries for files not managed by Lanzaboote (e.g. a leftover vendor `.efi`) are tolerable; an unsigned *current-generation* kernel or bootloader is not.

**Do not proceed to Task 3 until this passes.** Enrolling keys while signing is broken is what bricks a boot.

- [ ] **Step 8: 🧑 HUMAN — Reboot and confirm nothing regressed**

Run: `reboot`
Expected: normal boot with the LUKS passphrase. Secure Boot is still off, so this only proves the signed bootloader works.

---

### Task 3: Firmware enrollment (🧑 HUMAN — hardest step to undo)

**Files:**
- Modify: `modules/nixos/secureboot.nix`

**Interfaces:**
- Consumes: verified signing from Task 2.
- Produces: firmware in user mode with our keys; `bootctl status` reporting Secure Boot enabled.

- [ ] **Step 1: 🧑 HUMAN — Put the firmware in setup mode**

Reboot into BIOS (`Del`) → Settings → Security → Secure Boot → set mode to **Custom** → Key Management → **Delete All Secure Boot Variables** → save and reboot.

Expected: the system still boots normally (Secure Boot is now in setup mode, enforcing nothing).

- [ ] **Step 2: Enable auto-enrollment**

In `modules/nixos/secureboot.nix`, inside the `boot.lanzaboote` block, add below `autoGenerateKeys.enable = true;`:

```nix
    # Writes PK/KEK/db .auth files to the ESP; systemd-boot performs the
    # actual firmware enrollment on the next boot, which only works while
    # the firmware is in setup mode. includeMicrosoftKeys defaults to true
    # and stays true — the Dell's option ROMs may be signed with them.
    # autoReboot stays off so the enrolling reboot is a conscious act.
    autoEnrollKeys.enable = true;
```

- [ ] **Step 3: Format, build, and commit**

```bash
nix fmt && nixos-rebuild build --flake .#nixps
git add modules/nixos/secureboot.nix
git commit -m "feat(secureboot): auto-enroll nixps secure boot keys

systemd-boot enrolls PK/KEK/db on the next boot while the firmware is in
setup mode. Microsoft keys are retained so the Dell's option ROMs still
load."
```

- [ ] **Step 4: 🧑 HUMAN — Activate and reboot to enroll**

Run: `sudo nixos-rebuild switch --flake .#nixps` then `reboot`

Expected: during this boot, systemd-boot enrolls the keys. The boot may appear to restart itself once — that is normal.

- [ ] **Step 5: 🧑 HUMAN — Confirm enrollment**

Run: `bootctl status | grep -i "secure boot"`
Expected: `Secure Boot: enabled (user)`.

If it reports `setup` or `disabled`, re-enter BIOS and turn Secure Boot on explicitly, then re-check. If it reports enabled but the machine will not boot, disable Secure Boot in BIOS to recover, then investigate — do not proceed to Task 4.

---

### Task 4: TPM2 sealing at PCR 7

Ordering is load-bearing: PCR 7 measures Secure Boot state, so this must happen **after** Task 3. Enrolling earlier seals against a value that is about to change, and unlock then fails silently.

**Files:**
- Modify: `modules/nixos/secureboot.nix`

**Interfaces:**
- Consumes: `Secure Boot: enabled (user)` from Task 3.
- Produces: a TPM2 keyslot on `cryptroot`; passphrase-less boot.

- [ ] **Step 1: 🧑 HUMAN — Confirm the TPM is present**

Run: `systemd-analyze has-tpm2`
Expected: `yes`. If not, stop — the rest of this task is impossible on this hardware.

- [ ] **Step 2: 🧑 HUMAN — Seal the LUKS key to PCR 7**

```bash
sudo systemd-cryptenroll \
  --tpm2-device=auto \
  --tpm2-pcrs=7 \
  /dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9
```

Expected: prompts for the existing passphrase, then reports a new TPM2 keyslot. **This adds a keyslot; it does not remove the passphrase.** Never pass `--wipe-slot`.

- [ ] **Step 3: 🧑 HUMAN — Confirm the keyslot exists**

Run: `sudo cryptsetup luksDump /dev/disk/by-uuid/567ccf9f-ee66-4985-aa2c-e9850a0198e9 | grep -A3 -i token`
Expected: a `systemd-tpm2` token is listed, alongside the original passphrase keyslot.

- [ ] **Step 4: Tell the initrd to try the TPM**

In `modules/nixos/secureboot.nix`, add before the `environment.systemPackages` line:

```nix
  # Unlock cryptroot from the TPM2 keyslot enrolled at PCR 7. The
  # passphrase keyslot remains as the fallback.
  boot.initrd.luks.devices."cryptroot".crypttabExtraOpts = ["tpm2-device=auto"];
```

- [ ] **Step 5: Format, build, and commit**

```bash
nix fmt && nixos-rebuild build --flake .#nixps
git add modules/nixos/secureboot.nix
git commit -m "feat(secureboot): unlock nixps cryptroot from the TPM

Seals to PCR 7 only, which tracks Secure Boot state and so survives
kernel and generation updates without re-enrolling. The passphrase
keyslot is retained as the fallback."
```

- [ ] **Step 6: 🧑 HUMAN — Activate and reboot**

Run: `sudo nixos-rebuild switch --flake .#nixps` then `reboot`
Expected: the machine boots to the login screen **without** asking for the LUKS passphrase.

- [ ] **Step 7: 🧑 HUMAN — Test the fallback**

Reboot again and, at the unlock stage, press `Esc` (or wait out the TPM attempt) to reach the passphrase prompt. Enter the passphrase.
Expected: it unlocks. This proves you are not locked out if the TPM state ever changes.

- [ ] **Step 8: 🧑 HUMAN — Final verification sweep**

```bash
bootctl status | grep -i "secure boot"      # Secure Boot: enabled (user)
sudo sbctl verify                            # all current-generation files signed
systemd-analyze has-tpm2                     # yes
```

---

## Post-Implementation Notes

- **Kernel and generation updates need no action.** PCR 7 does not change when the kernel changes; Lanzaboote signs each new generation automatically.
- **A BIOS update may break unlock** if it alters Secure Boot state. Recovery is the passphrase, then re-run Task 4 Step 2.
- **Generations built before Task 2 are unsigned** and will not boot under Secure Boot. They age out via `configurationLimit = 5`.
- **`measuredBoot`/pcrlock was deliberately deferred** — see the spec's sealing section for the reasoning and when to revisit.
- **`nixmachine` was intentionally excluded.** If it ever gets a LUKS root, this module is reusable as-is; until then, do not import it there.
