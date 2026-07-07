# age-encrypted secrets decrypted at activation time using the host's
# SSH host key (see age.identityPaths). Each secret lands at
# /run/agenix/<name> with the owner/mode specified here.
{user, ...}: {
  age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  age.secrets =
    builtins.mapAttrs (_: file: {
      inherit file;
      owner = user.me.username;
      group = "users";
      mode = "0400";
    })
    (import ../../secrets/definitions.nix);
}
