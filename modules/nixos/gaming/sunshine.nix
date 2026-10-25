# Sunshine — self-hosted game-stream host; Moonlight clients on your other
# devices connect to it. Model A: it KMS-captures the physical gamescope →
# Steam session and mirrors it. Runs as jie's user service bound to
# graphical-session.target (brought up by the gamescope-session wrapper in
# session.nix), so it is live during the session and stops when you exit Steam.
#   openFirewall → Moonlight discovery + stream ports
#   capSysAdmin  → CAP_SYS_ADMIN, required for KMS/DRM capture of the output
#   uinput (Moonlight virtual controllers) + Avahi discovery are auto-enabled.
# First connection needs a one-time PIN pairing at https://<host>:47990.
# ⚠️  gamescope direct scanout can defeat KMS capture (black frame). If that
#     happens it needs an on-hardware tweak (force composition) — the Nix build
#     is unaffected either way.
{
  services.sunshine = {
    enable = true;
    openFirewall = true;
    capSysAdmin = true;
    autoStart = true;
  };

  # HACK: upstream sunshine.nix still sets the obsolete avahi.publish.* options
  # (mkDefault), which trips evaluation warnings. Null them out and set the
  # settings-based equivalents Moonlight discovery needs. Drop once nixpkgs
  # migrates the sunshine module.
  services.avahi = {
    publish = {
      enable = null;
      userServices = null;
    };
    settings.publish = {
      disable-publishing = false;
      disable-user-service-publishing = false;
      publish-addresses = true;
    };
  };
}
