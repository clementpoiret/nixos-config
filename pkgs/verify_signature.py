"""Verify detached release signatures using only the supplied public keys."""

from pathlib import Path
import subprocess
import sys
import tempfile


def verify_signature(key, signature, data):
    # Keep verification independent of the user's keyring and trust database.
    with tempfile.TemporaryDirectory(prefix="release-signature-") as directory:
        keyring = Path(directory) / "release.gpg"
        subprocess.run([
            "gpg", "--no-options", "--homedir", directory, "--batch",
            "--dearmor", "--output", str(keyring), str(key),
        ], check=True)
        subprocess.run([
            "gpgv", "--homedir", directory, "--keyring", str(keyring),
            str(signature), str(data),
        ], check=True)


if __name__ == "__main__":
    key, signature, data = sys.argv[1:]
    verify_signature(key, signature, data)
