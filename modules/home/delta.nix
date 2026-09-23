{ ... }:
{
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    enableJujutsuIntegration = true;

    options = {
      side-by-side = true;
      line-numbers = true;
      navigate = true;
      hyperlinks = true;
    };
  };
}
