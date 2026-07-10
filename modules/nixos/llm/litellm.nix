# LiteLLM — unified OpenAI-compatible gateway for cloud LLMs. Fronts both
# Anthropic (Claude) and OpenAI so Open WebUI and Karakeep need one backend and both
# provider keys live in one place. Localhost-only; the keys come from a
# root-only env file (out of the Nix store), referenced as os.environ/... in the
# model list. Default port 8080 would clash with metatube, so use 4000.
_: {
  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 4000;
    environmentFile = "/var/lib/litellm-secrets/env"; # ANTHROPIC_API_KEY + OPENAI_API_KEY
    settings.model_list = [
      {
        model_name = "Claude Opus 4.8 (high)";
        litellm_params = {
          model = "anthropic/claude-opus-4-8";
          api_key = "os.environ/ANTHROPIC_API_KEY";
          reasoning_effort = "high";
        };
      }
      {
        model_name = "OpenAI GPT-5.5 (high)";
        litellm_params = {
          model = "openai/gpt-5.5";
          api_key = "os.environ/OPENAI_API_KEY";
          reasoning_effort = "high";
        };
      }
      {
        # Cheap/fast model for Karakeep's bookmark auto-tagging + image tagging
        # (high-volume work; no reasoning_effort — Haiku doesn't accept it).
        model_name = "Claude Haiku 4.5";
        litellm_params = {
          model = "anthropic/claude-haiku-4-5";
          api_key = "os.environ/ANTHROPIC_API_KEY";
        };
      }
      {
        # Embeddings for Karakeep's semantic search (OpenAI, via the key above).
        model_name = "text-embedding-3-small";
        litellm_params = {
          model = "openai/text-embedding-3-small";
          api_key = "os.environ/OPENAI_API_KEY";
        };
      }
    ];
  };

  # Root-only dir for the shared provider-key env file.
  systemd.tmpfiles.rules = ["d /var/lib/litellm-secrets 0700 root root -"];
}
