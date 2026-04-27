{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  rustPlatform ? pkgs.rustPlatform,
  fetchFromGitHub ? pkgs.fetchFromGitHub,
  makeWrapper ? pkgs.makeWrapper,
  jujutsu ? pkgs.jujutsu or pkgs.jj,
}:

rustPlatform.buildRustPackage rec {
  pname = "blazingjj";
  version = "0.8.0";

  src = fetchFromGitHub {
    owner = "blazingjj";
    repo = "blazingjj";
    rev = "v${version}";
    hash = "sha256-vefD93gzT6WEplpnYiENtzXLSeXBo+9K3/RYpSBafDs=";
  };

  cargoHash = "sha256-E/xddxdvCDWH1xPn/CPXFyJIHg1Dy6EG3VZMZouWHQY=";

  nativeBuildInputs = [
    makeWrapper
  ];

  nativeCheckInputs = [
    jujutsu
  ];

  postInstall = ''
    wrapProgram $out/bin/blazingjj \
      --prefix PATH : ${lib.makeBinPath [ jujutsu ]}
  '';

  meta = {
    description = "TUI for Jujutsu/jj";
    homepage = "https://github.com/blazingjj/blazingjj";
    changelog = "https://github.com/blazingjj/blazingjj/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.asl20;
    mainProgram = "blazingjj";
    maintainers = [ "clementpoiret" ];
  };
}
