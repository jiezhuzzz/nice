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
}
