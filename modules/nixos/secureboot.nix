# modules/nixos/secureboot.nix
# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
# Imported by hosts/nixos/nixps/default.nix only — nixmachine has no LUKS
# root and stays on plain systemd-boot.
#
# One-time firmware step, not expressible in Nix:
#   BIOS (Del) -> Settings -> Security -> Secure Boot -> Custom mode
#   -> Delete All Secure Boot Variables   (puts the firmware in setup mode)
# systemd-boot can only auto-enroll our keys while the firmware is in setup
# mode. `Restore Factory Keys` in the same menu is the way back.
{
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
  };

  # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock. This is
  # already the nixpkgs default, so setting it changes nothing today — it is
  # pinned explicitly so a future default flip cannot silently break unlock.
  boot.initrd.systemd.enable = true;

  # For inspecting and verifying Secure Boot state.
  environment.systemPackages = [pkgs.sbctl];
}
