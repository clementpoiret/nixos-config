let
  protonBridgeCertificate = ../../certs/cert.pem;
in
{
  programs.thunderbird = {
    enable = true;

    # Trust Proton Mail Bridge only inside Thunderbird, not system-wide.
    policies.Certificates.Install = [ "${protonBridgeCertificate}" ];
  };
}
