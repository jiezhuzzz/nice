# Open WebUI — chat UI for LLMs. Talks to LiteLLM (127.0.0.1:4000) as its single
# OpenAI-compatible backend, so it holds no real API keys — those live in
# litellm.nix. LAN-exposed on 8081 (open-webui is a native service listening on
# 0.0.0.0, so the nftables input rule below genuinely restricts it to the LAN).
# OPENAI_API_KEY here is a throwaway: Open WebUI only enables the connection when
# the key is non-empty, and LiteLLM on localhost does no auth, so its value is
# ignored — hence it can sit in the store as a non-secret.
_: {
  services.open-webui = {
    enable = true;
    host = "0.0.0.0";
    port = 8081;
    environment = {
      OPENAI_API_BASE_URL = "http://127.0.0.1:4000/v1";
      OPENAI_API_KEY = "sk-litellm";
      ENABLE_OLLAMA_API = "False"; # cloud only, no local ollama
    };
  };

  networking.firewall.extraInputRules = ''
    ip saddr 192.168.86.0/24 tcp dport 8081 accept
  '';
}
