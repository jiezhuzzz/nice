{inputs, ...}: let
  # Anthropic's marketplace, pinned in flake.lock (see flake.nix). One repo of
  # ~35 plugins; everything below is a subdirectory of it, so there is exactly
  # one thing to update.
  officialPlugins = "${inputs.claude-plugins-official}/plugins";

  communityPlugins = inputs.claude-plugins-community;

  mattpocockSkills = "${inputs.mattpocock-skills}/skills";
in {
  # Each entry is linked whole as ~/.config/claude/skills/<name> and loaded as
  # a personal plugin, so its skills, agents, commands and hooks all register
  # — namespaced under the attribute name. An attribute set rather than a
  # list: the name becomes that directory, where the list form derives it from
  # the store path and yields churn like `bxa1s0m3h4sh-source`.
  #
  # Anything else from the marketplace is a one-liner away; `ls
  # ${officialPlugins}` lists all ~35.
  programs.claude-code.plugins = {
    claude-code-setup = "${officialPlugins}/claude-code-setup";
    code-simplifier = "${officialPlugins}/code-simplifier";
    feature-dev = "${officialPlugins}/feature-dev";
    eli5 = "${communityPlugins}/eli5";
    inherit (inputs) caveman;
  };

  # Single skills, linked as ~/.config/claude/skills/<name> without their
  # plugin: only the named directory comes along, so sibling skills the text
  # mentions (`superpowers:test-driven-development`) are not installed.
  programs.claude-code.skills = {
    systematic-debugging = "${inputs.superpowers}/skills/systematic-debugging";
    improve-codebase-architecture = "${mattpocockSkills}/engineering/improve-codebase-architecture";
    codebase-design = "${mattpocockSkills}/engineering/codebase-design";
    domain-modeling = "${mattpocockSkills}/engineering/domain-modeling";
    grilling = "${mattpocockSkills}/productivity/grilling";
    # Authored in this repo, under ./skills/<name> beside this file.
    concretize = ./skills/concretize;
  };
}
