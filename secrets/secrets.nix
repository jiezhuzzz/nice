# agenix recipients manifest. Consumed by the `agenix` CLI (not by Nix):
# it reads this file to know which public keys may decrypt each secret.
#
# Add new secrets by giving them a name and a list of recipients. Recipients
# can be host SSH pubkeys (deployed systems) and/or user pubkeys (for editing).
#
# Usage:
#   nix run github:ryantm/agenix -- -e ssh/github.age
let
  # Host keys (from /etc/ssh/ssh_host_ed25519_key.pub on each machine). Every
  # host jie logs in from carries the whole personal set, so adding a machine
  # here is one edit plus one `agenix -r` rather than a per-secret grant.
  # Service credentials below stay scoped to the box that runs the service.
  nixps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApiDrorjoUu3XSvuzSEwDyMauOtmcqeRKW9SJWN1PT7";
  nixair = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILd3vgPew3ZkrxUrPxWieOlctLjqw9r0MH48HsAbNfcb";
  nixmini = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFdGfQiCHk30nWql1kwmIVPNzIkM9io+7Q9AqA4+y7k";
  nixneo = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJAekmUrW6WXWL2IWlhuvGQSq3MM2Zf94UJBzdZHEClJ";
  nixmachine = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBhpaKcPL+8+O0D+Vb4wRdvVEGOv2zfeTSCgVRR9evZX";

  # User keys (for editing secrets and as a recovery path).
  password-manager = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkFCNadE6kTViKssYg8SBEHf9H0BEa92p3l0UfMELOF";

  allHosts = [nixps nixair nixmini nixneo nixmachine];
  allUsers = [password-manager];
  allRecipients = allHosts ++ allUsers;
in {
  "ssh/github.age".publicKeys = allRecipients;
  "ssh/git-signing.age".publicKeys = allRecipients;
  "ssh/chameleon.age".publicKeys = allRecipients;
  "ssh/lab.age".publicKeys = allRecipients;
  "ssh/home.age".publicKeys = allRecipients;
  "rclone/gdrive.age".publicKeys = allRecipients;
  "rclone/box.age".publicKeys = allRecipients;
  # Glance's air-quality widget (WAQI API token). Only nixmachine runs glance;
  # password-manager is kept as the editing/recovery recipient.
  "glance/waqi-token.age".publicKeys = [nixmachine password-manager];
  # Caddy's ACME DNS-01 token (Cloudflare, scoped to DNS edits on jiezhu.me).
  # Only nixmachine runs caddy; password-manager is the editing/recovery recipient.
  "caddy/cloudflare-token.age".publicKeys = [nixmachine password-manager];
  # Anthropic and OpenAI provider keys consumed by the local LiteLLM gateway.
  # Only nixmachine needs to decrypt them at runtime.
  "llm/provider-keys.age".publicKeys = [nixmachine password-manager];
  # SearXNG's server.secret_key. Only nixmachine runs searxng; password-manager
  # is the editing/recovery recipient.
  "searxng/secret-key.age".publicKeys = [nixmachine password-manager];
  # Vaultwarden's ADMIN_TOKEN (an Argon2 PHC hash, not a plaintext password).
  # Only nixmachine runs vaultwarden; password-manager is the editing/recovery
  # recipient.
  "vaultwarden/admin-token.age".publicKeys = [nixmachine password-manager];
  # Miniflux's seed admin account (ADMIN_USERNAME/ADMIN_PASSWORD env file).
  "miniflux/admin-credentials.age".publicKeys = [nixmachine password-manager];
}
