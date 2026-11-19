{
  inputs,
  lib,
  ...
}:
let
  skillNames = [
    "cross-agent"
    "jujutsu"
    "optimize"
    "precision-review"
    "simplify"
  ];
  skillDirectories = [
    ".agents/skills"
    ".claude/skills"
    ".gemini/skills"
  ];
in
{
  home.file =
    builtins.listToAttrs (
      lib.concatMap (
        directory:
        map (skill: {
          name = "${directory}/${skill}";
          value.source = "${inputs.clementpoiret-skills}/skills/${skill}";
        }) skillNames
      ) skillDirectories
    )
    // {
      ".codex/AGENTS.md" = {
        force = true;
        source = ./agent-instructions/AGENTS.md;
      };
      ".claude/CLAUDE.md" = {
        force = true;
        source = ./agent-instructions/AGENTS.md;
      };
      ".config/opencode/AGENTS.md" = {
        force = true;
        source = ./agent-instructions/AGENTS.md;
      };
      ".gemini/AGENTS.md" = {
        force = true;
        source = ./agent-instructions/AGENTS.md;
      };
    };
}
