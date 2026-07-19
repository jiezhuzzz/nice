# modules/nixos/secureboot.nix
# UEFI Secure Boot for nixps via lanzaboote, plus TPM2-backed LUKS unlock.
# Imported by hosts/nixos/nixps/default.nix only — nixmachine has no LUKS
# root and stays on plain systemd-boot.
_: {
  # The systemd-based initrd is a prerequisite for TPM2 LUKS unlock. This is
  # already the nixpkgs default, so setting it changes nothing today — it is
  # pinned explicitly so a future default flip cannot silently break unlock.
  boot.initrd.systemd.enable = true;
}
