# LiteLLM — unified OpenAI-compatible gateway for cloud LLMs. Fronts both
# Anthropic (Claude) and OpenAI so Karakeep needs one backend and both provider
# keys live in one place. Localhost-only; the keys come from a root-only env
# file (out of the Nix store), referenced as os.environ/... in the model list.
# Default port 8080 would clash with metatube, so use 4000.
{config, ...}: {
  # Decrypted at activation to /run/agenix/litellm-provider-keys. systemd reads
  # the root-only env file before starting LiteLLM's DynamicUser process.
  age.secrets.litellm-provider-keys = {
    file = ../../secrets/llm/provider-keys.age;
    mode = "0400";
  };

  services.litellm = {
    enable = true;
    host = "127.0.0.1";
    port = 4000;
    environmentFile = config.age.secrets.litellm-provider-keys.path;
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
}
