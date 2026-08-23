{
  inputs,
  lib,
  ...
}:
let
  skillNames = [
    "change-contract"
    "cross-agent"
    "jujutsu"
    "simplify-after-green"
    "simplify-tests-after-green"
  ];
  skillDirectories = [
    ".agents/skills"
    ".claude/skills"
  ];
in
{
  home.file = builtins.listToAttrs (
    lib.concatMap (
      directory:
      map (skill: {
        name = "${directory}/${skill}";
        value.source = "${inputs.clementpoiret-skills}/skills/${skill}";
      }) skillNames
    ) skillDirectories
  );
}
