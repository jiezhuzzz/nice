# LiteLLM — unified OpenAI-compatible gateway for cloud LLMs. Fronts both
# Anthropic (Claude) and OpenAI so Open WebUI needs only one backend and both
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
    ];
  };

  # Root-only dir for the shared provider-key env file.
  systemd.tmpfiles.rules = ["d /var/lib/litellm-secrets 0700 root root -"];
}
