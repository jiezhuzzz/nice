# LLM stack for nixmachine: LiteLLM gateway (holds the provider keys) + Open
# WebUI chat frontend pointed at it.
{...}: {
  imports = [
    ./litellm.nix
    ./open-webui.nix
  ];
}
