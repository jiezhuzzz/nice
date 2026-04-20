# agenix recipients manifest. Consumed by the `agenix` CLI (not by Nix):
# it reads this file to know which public keys may decrypt each secret.
#
# Add new secrets by giving them a name and a list of recipients. Recipients
# can be host SSH pubkeys (deployed systems) and/or user pubkeys (for editing).
#
# Usage:
#   nix run github:ryantm/agenix -- -e github-ssh-key.age
let
  # Host keys (from /etc/ssh/ssh_host_ed25519_key.pub on each machine).
  nixps = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApiDrorjoUu3XSvuzSEwDyMauOtmcqeRKW9SJWN1PT7";
  nixair = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILd3vgPew3ZkrxUrPxWieOlctLjqw9r0MH48HsAbNfcb";
  nixmini = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJFdGfQiCHk30nWql1kwmIVPNzIkM9io+7Q9AqA4+y7k";

  # User keys (for editing secrets and as a recovery path).
  password-manager = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIkFCNadE6kTViKssYg8SBEHf9H0BEa92p3l0UfMELOF";

  allHosts = [nixps nixair nixmini];
  allUsers = [password-manager];
  allRecipients = allHosts ++ allUsers;
in {
  "github-ssh-key.age".publicKeys = allRecipients;
  "git-signing-key.age".publicKeys = allRecipients;
}
