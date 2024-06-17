{ pkgs, ... }: 
{
  home.packages = (with pkgs; [ master.floorp ]);
}
