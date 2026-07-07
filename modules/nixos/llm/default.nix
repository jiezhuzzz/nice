# LLM stack for nixmachine: LiteLLM gateway (holds the provider keys) + Open
# WebUI chat frontend pointed at it.
{...}: {
  imports = [
    ./langgraph-testfix.nix # nixpkgs workaround so open-webui's langgraph dep builds
    ./litellm.nix
    ./open-webui.nix
  ];
}
