# Karakeep — self-hosted "bookmark everything" app (formerly Hoarder): save
# links/notes/images, auto-tag with an LLM, full-text search, archive pages.
# Native NixOS service; the module also stands up its own Meilisearch (full-text
# search, localhost:7700) and a headless-chromium worker (screenshots/archival,
# localhost:9222) — both internal, so only the web UI needs a firewall hole.
#
# Secrets (MEILI_MASTER_KEY, NEXTAUTH_SECRET) are auto-generated on first start
# by the karakeep-init unit into /var/lib/karakeep/settings.env — no agenix
# wiring required, unlike glance/litellm.
#
# The Next.js server binds 0.0.0.0; its default port 3000 is moved to 8084 to
# sit alongside the other homelab web UIs (stirling 8082, glance 8083), and the
# nftables input rule restricts it to the home LAN. Reachable at
# http://nixmachine.local:8084 — on the first visit, create the admin account
# (sign-ups stay open until you add DISABLE_SIGNUPS = "true" below).
_: {
  services.karakeep = {
    enable = true;
    extraEnvironment = {
      PORT = "8084";
      # This box is declaratively managed, so silence the in-app upgrade nag.
      DISABLE_NEW_RELEASE_CHECK = "true";
    };
  };

  # LAN-only, following the same nftables pattern as the other web UIs on this box.
  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 8084 accept
  '';
}
