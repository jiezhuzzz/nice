# Xuewen — self-hosted paper manager (github:jiezhuzzz/xuewen). No nixpkgs
# package: the flake input carries both the build and this service module.
# Tailnet-only — binds 127.0.0.1, opens no firewall port, caddy is the only way
# in. 8087 because metatube holds 8080 and stirling/glance/karakeep/searx/
# miniflux take 8082-8086.
#
# The web UI has NO authentication and its mutating endpoints answer anyone who
# reaches them, so the tailnet is the entire access control here — never give
# this a LAN port or a non-loopback bind.
#
# Library, SQLite database and search index live under /var/lib/xuewen; drop
# PDFs into /var/lib/xuewen/inbox to ingest them.
#
# Summaries and citation parsing go through the local LiteLLM gateway exactly
# like karakeep. Agent Ask is the exception — see below. Semantic search and the
# daily arXiv feed stay off: both need [ai.embedding] plus a Qdrant server
# (services.qdrant.enable + settings.search.qdrant_url).
{
  config,
  inputs,
  ...
}: {
  imports = [inputs.xuewen.nixosModules.default];

  services.xuewen = {
    enable = true;
    port = 8087;

    settings.ai = {
      # LiteLLM speaks the OpenAI API and holds both provider keys (litellm.nix,
      # :4000). It has no master key (localhost-only), so any non-empty string
      # satisfies the client — a placeholder, not a secret. If LiteLLM ever gets
      # a master key, move this to api_key_env + environmentFile.
      base_url = "http://127.0.0.1:4000/v1";
      api_key = "litellm-local";
      # Default for the uses below — both are high-volume, so the cheap model.
      # The name must match litellm.nix's model_list.
      model = "Claude Haiku 4.5";
      summary = {}; # per-paper library summaries
      citations = {}; # parses only the references the pattern matcher misses

      # Agent Ask — the reader's Ask tab, and the gate on the code-attach
      # endpoint (PUT /api/papers/{id}/code clones into
      # <library_root>/agent/<paper_id>/repo). Unlike everything above it does
      # NOT go through LiteLLM: the Claude Agent SDK talks to Anthropic
      # directly, with ANTHROPIC_API_KEY from environmentFile below. Model left
      # unset — the SDK's own default. Upstream's module points .runner at its
      # packaged agent-runner and drops MemoryDenyWriteExecute (node's JIT
      # needs writable-then-executable pages).
      agent.claude_code = {};
    };

    # ANTHROPIC_API_KEY for the agent SDK. Same encrypted file LiteLLM reads,
    # decrypted under its own name so this module doesn't depend on litellm.nix
    # being imported. (It also carries OPENAI_API_KEY, unused here until an
    # [ai.agent.codex] section joins the one above.)
    environmentFile = config.age.secrets.xuewen-provider-keys.path;
  };

  age.secrets.xuewen-provider-keys = {
    file = ../../secrets/llm/provider-keys.age;
    mode = "0400";
  };
}
