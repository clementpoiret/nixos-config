{
  fetchFromGitLab,
  libdisplay-info_0_3,
}:

# The pinned Niri source requires the 0.2 ABI; use the host's library toolchain.
libdisplay-info_0_3.overrideAttrs (
  finalAttrs: _: {
    version = "0.2.0";
    src = fetchFromGitLab {
      domain = "gitlab.freedesktop.org";
      owner = "emersion";
      repo = "libdisplay-info";
      tag = finalAttrs.version;
      hash = "sha256-6xmWBrPHghjok43eIDGeshpUEQTuwWLXNHg7CnBUt3Q=";
    };
  }
)
