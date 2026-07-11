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
# AI features (bookmark auto-tagging, image tagging, and semantic-search
# embeddings) run through the local LiteLLM gateway — see extraEnvironment below.
#
# The Next.js server binds 0.0.0.0; its default port 3000 is moved to 8084 to
# sit alongside the other homelab web UIs (stirling 8082, glance 8083).
# Use https://karakeep.jiezhu.me — NEXTAUTH_URL below makes auth cookies
# Secure-only, so logging in over plain http://nixmachine.local:8084 fails.
# The admin account exists; sign-ups are disabled (DISABLE_SIGNUPS below).
_: {
  # pnpm 9.15.9 is karakeep's build-time tool (used by karakeep-init to build the
  # Next.js frontend); nixpkgs marked it insecure. The vuln is build-time only, so
  # allow it here until upstream karakeep bumps its pnpm. Remove this when it does.
  nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];

  services.karakeep = {
    enable = true;
    browser.enable = false;
    extraEnvironment = {
      PORT = "8084";
      # This box is declaratively managed, so silence the in-app upgrade nag.
      DISABLE_NEW_RELEASE_CHECK = "true";
      # Single-user instance and the admin account exists — don't let anyone
      # on the LAN/tailnet register more accounts.
      DISABLE_SIGNUPS = "true";

      # Auth callbacks/redirects must match how the app is reached from
      # outside — the HTTPS name served by caddy.nix. LAN-direct
      # http://nixmachine.local:8084 may redirect logins to this URL.
      NEXTAUTH_URL = "https://karakeep.jiezhu.me";

      # ---- AI features via the local LiteLLM gateway (llm/litellm.nix, :4000) ----
      # Karakeep speaks the OpenAI API; point it at LiteLLM, which fronts Claude
      # and OpenAI. LiteLLM has no master key (localhost-only), so any non-empty
      # key satisfies the OpenAI client — this is a placeholder, not a secret. If
      # you ever set a LiteLLM master key, move OPENAI_API_KEY to an environmentFile.
      OPENAI_BASE_URL = "http://127.0.0.1:4000/v1";
      OPENAI_API_KEY = "litellm-local";
      # Auto-tagging + image tagging on cheap/fast Haiku; embeddings (semantic
      # search) on OpenAI text-embedding-3-small. Names match LiteLLM's model_list.
      INFERENCE_TEXT_MODEL = "Claude Haiku 4.5";
      INFERENCE_IMAGE_MODEL = "Claude Haiku 4.5";
      EMBEDDING_TEXT_MODEL = "text-embedding-3-small";
    };
  };

  # Upstream has no openFirewall option (the port is an opaque env var, so the
  # module can't know it); allowedTCPPorts is exactly what openFirewall would do.
  networking.firewall.allowedTCPPorts = [8084];
}
