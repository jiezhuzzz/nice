# 1Password CLI + GUI. The GUI enables the system-auth polkit helper and
# the browser integration socket; polkitPolicyOwners is the list of users
# allowed to unlock via system auth.
{...}: let
  user = import ../../../users/jie.nix;
in {
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [user.me.username];
  };
}
