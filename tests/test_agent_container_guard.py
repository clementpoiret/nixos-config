from __future__ import annotations

import importlib.util
import os
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SOURCE = Path(
    os.environ.get(
        "AGENT_CONTAINER_GUARD_SOURCE",
        Path(__file__).parents[1] / "pkgs/agent-container-tools/guard.py",
    )
)


def load_guard():
    if not SOURCE.exists():
        raise AssertionError(f"agent container guard is missing: {SOURCE}")
    spec = importlib.util.spec_from_file_location("agent_container_guard", SOURCE)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class AgentContainerGuardTest(unittest.TestCase):
    def setUp(self) -> None:
        self.guard = load_guard()
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.home = Path(self.temporary.name) / "home"
        self.workspace = self.home / "work" / "project"
        self.workspace.mkdir(parents=True)
        self.executables = {
            "podman": "/tools/podman",
            "buildah": "/tools/buildah",
        }

    def invocation(
        self,
        tool: str,
        arguments: list[str],
        *,
        profile: str = "local-codex-cli-container-engine (enforce)",
        environment: dict[str, str] | None = None,
        cwd: Path | None = None,
    ):
        return self.guard.build_invocation(
            tool,
            arguments,
            environment
            or {
                "HOME": str(self.home),
                "PATH": "/host/path",
                "LANG": "en_US.UTF-8",
                "SSH_AUTH_SOCK": "/run/user/1000/ssh-agent",
                "AWS_SECRET_ACCESS_KEY": "secret",
                "CONTAINERS_CONF": "/host/containers.conf",
            },
            cwd or self.workspace,
            profile,
            uid=1234,
            home=self.home,
            executables=self.executables,
            safe_path="/tools/bin",
            containers_conf="/tools/containers.conf",
            storage_conf="/tools/storage.conf",
        )

    def test_codex_invocation_uses_an_isolated_store_and_scrubbed_environment(self) -> None:
        invocation = self.invocation("podman", ["run", "--rm", "alpine", "true"])

        state = self.home / ".local/share/containers/agents/codex"
        runtime = Path("/run/user/1234/agent-containers/codex")
        self.assertEqual(invocation.argv[0], "/tools/podman")
        self.assertIn(str(state / "storage"), invocation.argv)
        self.assertIn(str(runtime / "storage"), invocation.argv)
        self.assertEqual(invocation.environment["HOME"], str(state / "home"))
        self.assertEqual(invocation.environment["REGISTRY_AUTH_FILE"], str(state / "auth.json"))
        self.assertEqual(invocation.environment["XDG_RUNTIME_DIR"], str(runtime))
        self.assertEqual(invocation.environment["LANG"], "en_US.UTF-8")
        self.assertNotIn("SSH_AUTH_SOCK", invocation.environment)
        self.assertNotIn("AWS_SECRET_ACCESS_KEY", invocation.environment)
        self.assertEqual(invocation.environment["CONTAINERS_CONF"], "/tools/containers.conf")

    def test_claude_invocation_uses_a_different_store(self) -> None:
        invocation = self.invocation(
            "buildah",
            ["bud", "."],
            profile="local-claude-code-container-engine (enforce)",
        )

        self.assertIn(
            str(self.home / ".local/share/containers/agents/claude/storage"),
            invocation.argv,
        )
        self.assertEqual(
            invocation.environment["XDG_RUNTIME_DIR"],
            "/run/user/1234/agent-containers/claude",
        )

    def test_auth_file_is_private_and_existing_credentials_are_preserved(self) -> None:
        auth_file = self.home / "state" / "auth.json"
        auth_file.parent.mkdir()

        self.guard._ensure_private_auth_file(auth_file, uid=os.getuid())
        self.assertEqual(auth_file.read_text(encoding="utf-8"), "{}")
        self.assertEqual(stat.S_IMODE(auth_file.stat().st_mode), 0o600)

        auth_file.write_text('{"auths":{"registry.example":{}}}', encoding="utf-8")
        auth_file.chmod(0o644)
        self.guard._ensure_private_auth_file(auth_file, uid=os.getuid())
        self.assertEqual(
            auth_file.read_text(encoding="utf-8"),
            '{"auths":{"registry.example":{}}}',
        )
        self.assertEqual(stat.S_IMODE(auth_file.stat().st_mode), 0o600)

    def test_inherited_non_stdio_file_descriptors_are_closed(self) -> None:
        with (
            mock.patch.object(
                self.guard.os,
                "listdir",
                return_value=["0", "1", "2", "3", "11", "not-a-descriptor"],
            ),
            mock.patch.object(self.guard.os, "close") as close,
        ):
            self.guard._close_inherited_file_descriptors()

        self.assertEqual(close.call_args_list, [mock.call(3), mock.call(11)])

    def test_rejects_calls_outside_an_enforced_agent_broker(self) -> None:
        for profile in (
            "unconfined",
            "local-codex-cli (complain)",
            "local-agent-container-payload (enforce)",
        ):
            with self.subTest(profile=profile), self.assertRaisesRegex(
                self.guard.GuardError, "broker profile"
            ):
                self.invocation("podman", ["images"], profile=profile)

    def test_allows_workspace_build_contexts_and_bind_mounts(self) -> None:
        containerfile = self.workspace / "Containerfile"
        containerfile.write_text("FROM scratch\n", encoding="utf-8")
        source = self.workspace / "src"
        source.mkdir()

        build = self.invocation(
            "podman", ["build", "--file", "Containerfile", "."]
        )
        run = self.invocation(
            "podman", ["run", "--volume", f"{source}:/src:ro", "alpine"]
        )

        self.assertEqual(build.argv[-4:], ["build", "--file", "Containerfile", "."])
        self.assertEqual(run.argv[-4:], ["run", "--volume", f"{source}:/src:ro", "alpine"])

    def test_rejects_paths_outside_the_workspace(self) -> None:
        cases = (
            ["build", ".."],
            ["build", "..", "--tag", "example"],
            ["build", "--file", "/etc/passwd", "."],
            ["run", "--volume", "/etc:/host:ro", "alpine"],
            ["run", "-v", "../outside:/host", "alpine"],
            ["run", "-v../outside:/host", "alpine"],
            ["run", "--mount", "type=bind,src=/var,dst=/host", "alpine"],
            ["run", "--mount", "type=secret,src=/etc/passwd,target=/secret", "alpine"],
            ["run", "--cidfile", "/tmp/container-id", "alpine"],
            ["build", "--iidfile", "/tmp/image-id", "."],
            ["build", "--output", "type=local,dest=/tmp/output", "."],
            ["push", "--digestfile", "/tmp/digest", "example"],
            ["push", "--sign-by-sigstore", "/etc/sigstore.yaml", "example"],
            ["load", "--input", "/tmp/image.tar"],
        )
        for arguments in cases:
            with self.subTest(arguments=arguments), self.assertRaisesRegex(
                self.guard.GuardError, "workspace"
            ):
                self.invocation("podman", list(arguments))

    def test_allows_workspace_output_paths(self) -> None:
        invocation = self.invocation(
            "podman",
            ["build", "--iidfile", "artifacts/image-id", "."],
        )

        self.assertEqual(
            invocation.argv[-4:],
            ["build", "--iidfile", "artifacts/image-id", "."],
        )

    def test_rejects_unscoped_working_directories(self) -> None:
        hidden_workspace = self.home / ".config" / "agent"
        hidden_workspace.mkdir(parents=True)

        for cwd in (self.home, hidden_workspace, Path("/etc")):
            with self.subTest(cwd=cwd), self.assertRaisesRegex(
                self.guard.GuardError, "workspace"
            ):
                self.invocation("podman", ["images"], cwd=cwd)

    def test_compact_env_options_must_use_explicit_values(self) -> None:
        with self.assertRaisesRegex(self.guard.GuardError, "inherit"):
            self.invocation("podman", ["run", "-eAWS_SECRET_ACCESS_KEY", "alpine"])

        invocation = self.invocation(
            "podman", ["run", "-eMODE=development", "alpine"]
        )
        self.assertEqual(invocation.argv[-3:], ["run", "-eMODE=development", "alpine"])

    def test_rejects_host_escape_options_in_split_and_equals_forms(self) -> None:
        cases = (
            ["run", "--privileged", "alpine"],
            ["run", "--cap-add=SYS_ADMIN", "alpine"],
            ["run", "--device", "/dev/kvm", "alpine"],
            ["run", "--security-opt=apparmor=unconfined", "alpine"],
            ["run", "--pid", "host", "alpine"],
            ["run", "--userns=host", "alpine"],
            ["run", "--ipc=/proc/1/ns/ipc", "alpine"],
            ["run", "--network=host", "alpine"],
            ["run", "--env-host", "alpine"],
            ["run", "--preserve-fds=1", "alpine"],
            ["run", "--annotation", "run.oci.keep_original_groups=1", "alpine"],
            ["run", "--gpus", "all", "alpine"],
            ["run", "--device-read-bps", "/dev/sda:1mb", "alpine"],
            ["run", "--blkio-weight-device", "/dev/sda:100", "alpine"],
            ["run", "--cgroups", "disabled", "alpine"],
            ["run", "--log-driver", "passthrough", "alpine"],
            ["run", "--log-opt", "path=/tmp/container.log", "alpine"],
            ["run", "--userns-uid-map", "0:1000:1", "alpine"],
            ["build", "--build-context", "docs=/etc", "."],
            ["build", "--chrootdirs", "/etc", "."],
            ["push", "--encryption-key", "jwe:/etc/key.pem", "example"],
            ["commit", "--add-file", "/etc/passwd:/passwd", "container", "image"],
            ["--root", "/tmp/alternate", "images"],
            ["--url=unix:///run/user/1234/podman.sock", "images"],
        )
        for arguments in cases:
            with self.subTest(arguments=arguments), self.assertRaisesRegex(
                self.guard.GuardError, "not permitted"
            ):
                self.invocation("podman", list(arguments))

    def test_rejects_unsafe_management_subcommands(self) -> None:
        for tool, arguments in (
            ("podman", ["system", "service"]),
            ("podman", ["unshare", "cat", "/etc/shadow"]),
            ("podman", ["mount", "container"]),
            ("podman", ["kube", "play", "pod.yaml"]),
            ("podman", ["compose", "up"]),
            ("podman", ["container", "cp", "/etc/passwd", "example:/tmp"]),
            ("podman", ["image", "import", "/etc/passwd"]),
            ("podman", ["network", "create", "agent-network"]),
            ("podman", ["volume", "create", "--opt", "device=/etc", "data"]),
            ("buildah", ["unshare", "cat", "/etc/shadow"]),
            ("buildah", ["mount", "container"]),
        ):
            with self.subTest(tool=tool, arguments=arguments), self.assertRaisesRegex(
                self.guard.GuardError, "subcommand"
            ):
                self.invocation(tool, list(arguments))

    def test_rejects_unknown_tools_and_global_options(self) -> None:
        with self.assertRaisesRegex(self.guard.GuardError, "unsupported tool"):
            self.invocation("docker", ["images"])
        with self.assertRaisesRegex(self.guard.GuardError, "global option"):
            self.invocation("buildah", ["--debug", "images"])


if __name__ == "__main__":
    unittest.main()
