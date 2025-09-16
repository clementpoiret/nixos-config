{
  lib,
  stdenv,
  fetchFromGitHub,
  systemd,
  pkg-config,
  overrideCC,
  gcc15,
}:
let
  stdenv' = overrideCC stdenv gcc15;
in
stdenv'.mkDerivation rec {
  pname = "runapp";
  version = "0.4.1";

  src = fetchFromGitHub {
    owner = "c4rlo";
    repo = pname;
    rev = version;
    hash = "sha256-+dIawnBTf8QU0dv93NQUCgW60BrlUXljaoNnRQjfJZQ=";
  };

  strictDeps = true;
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ systemd ];

  postPatch = ''
    substituteInPlace Makefile --replace-warn "-march=native" ""
  '';

  buildFlags = [ "release" ];

  installFlags = [
    "prefix=$(out)"
    "install_runner="
  ];

  meta = with lib; {
    description = "Application runner for Linux desktop environments that integrate with systemd";
    homepage = "https://github.com/c4rlo/runapp";
    license = licenses.mit;
    maintainers = [ maintainers.clementpoiret ];
    platforms = platforms.linux;
  };
}
