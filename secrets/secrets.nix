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
  naptop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIApiDrorjoUu3XSvuzSEwDyMauOtmcqeRKW9SJWN1PT7";

  # User keys (add your personal SSH/age pubkey here so you can re-encrypt
  # secrets without being logged in on the host).
  # jie = "ssh-ed25519 AAAA... jie@somewhere";

  allHosts = [naptop];
  # allUsers = [jie];
  allRecipients = allHosts; # ++ allUsers;
in {
  "github-ssh-key.age".publicKeys = allRecipients;
  "git-signing-key.age".publicKeys = allRecipients;
}
