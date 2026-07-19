# modules/nixos/secureboot.nix
# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
# Imported by hosts/nixos/nixps/default.nix only — nixmachine has no LUKS
# root and stays on plain systemd-boot.
#
# One-time firmware step, not expressible in Nix. On this Dell the relevant
# menu is Secure Boot -> Enable Custom Mode -> Custom Mode Key Management.
# Clearing the enrolled PK there puts the firmware in setup mode, which is
# the only state in which systemd-boot will auto-enroll our keys.
#
# As shipped the machine has builtin-PK/KEK/db plus microsoft (`sbctl status`),
# and clearing them destroys Dell's OEM certificates — hence
# includeFirmwareBuiltinKeys below, so enrollment puts them back.
#
# Recovery is disabling Secure Boot in the firmware, which is always
# available and does not depend on restoring the factory keys. Note the NixOS
# install medium is unsigned and will NOT boot while Secure Boot is active.
{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = [inputs.lanzaboote.nixosModules.lanzaboote];

  # lanzaboote replaces systemd-boot, which modules/nixos/boot.nix enables.
  # configurationLimit is not repeated here: lanzaboote's option defaults to
  # config.boot.loader.systemd-boot.configurationLimit, which boot.nix still
  # sets to 5 even with the loader itself disabled.
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.lanzaboote = {
    enable = true;
    # sbctl 0.18's layout; lanzaboote reads keys/db/db.{pem,key} beneath it.
    pkiBundle = "/var/lib/sbctl";
    # `generate-sb-keys` runs `sbctl create-keys` once, guarded on the
    # absence of /var/lib/sbctl/keys.
    autoGenerateKeys.enable = true;

    # Writes PK/KEK/db .auth files to the ESP; systemd-boot performs the
    # actual firmware enrollment on the next boot, and only while the
    # firmware is in setup mode.
    autoEnrollKeys = {
      enable = true;
      # Re-enrol Dell's OEM certificates. Deleting the PK to reach setup mode
      # left builtin-db and builtin-KEK intact (`sbctl status`), and dropping
      # them can break vendor firmware updates via fwupd.
      includeFirmwareBuiltinKeys = true;
      # includeMicrosoftKeys defaults to true and stays true — option ROMs on
      # this machine may be signed with them.
      #
      # autoReboot stays off: the reboot that enrols is worth doing
      # deliberately, not as a side effect of `nixos-rebuild switch`.
    };
  };

  # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock. This is
  # already the nixpkgs default, so setting it changes nothing today — it is
  # pinned explicitly so a future default flip cannot silently break unlock.
  boot.initrd.systemd.enable = true;

  # Workaround for a lanzaboote v1.1.0 ordering bug. Lanzaboote defines both
  # `generate-sb-keys` (runs `sbctl create-keys`) and `fwupd-efi` (signs the
  # fwupd EFI app with the key that unit produces), but orders `fwupd-efi`
  # only `before = ["fwupd.service"]` — never after key generation. On a first
  # activation both start in the same transaction, `sbctl create-keys` takes a
  # few seconds, and `fwupd-efi` fails on the not-yet-existent db.key.
  # Harmless once keys exist; needed on first activation and after any key
  # regeneration. Remove if lanzaboote gains this dependency upstream.
  systemd.services.fwupd-efi = lib.mkIf config.services.fwupd.enable {
    after = ["generate-sb-keys.service"];
    wants = ["generate-sb-keys.service"];
  };

  # sbctl inspects/verifies Secure Boot state. efibootmgr edits the firmware
  # boot entries that bootctl can only report on — the repair tool if
  # enrollment leaves the machine booting the wrong entry.
  environment.systemPackages = [pkgs.sbctl pkgs.efibootmgr];
}
