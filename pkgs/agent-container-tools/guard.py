#!/usr/bin/env python3
from __future__ import annotations

import csv
import errno
import os
import pwd
import re
import stat
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Mapping, Sequence


class GuardError(ValueError):
    pass


@dataclass(frozen=True)
class Invocation:
    argv: list[str]
    environment: dict[str, str]
    directories: tuple[Path, ...]


AGENTS_BY_PROFILE = {
    "local-codex-cli-container-engine": "codex",
    "local-claude-code-container-engine": "claude",
}

ALLOWED_SUBCOMMANDS = {
    "podman": {
        "attach",
        "build",
        "commit",
        "cp",
        "create",
        "diff",
        "exec",
        "export",
        "history",
        "images",
        "import",
        "info",
        "inspect",
        "kill",
        "load",
        "login",
        "logout",
        "logs",
        "pause",
        "port",
        "ps",
        "pull",
        "push",
        "rename",
        "restart",
        "rm",
        "rmi",
        "run",
        "save",
        "search",
        "start",
        "stats",
        "stop",
        "tag",
        "top",
        "unmount",
        "unpause",
        "untag",
        "update",
        "version",
        "wait",
    },
    "buildah": {
        "add",
        "build",
        "bud",
        "commit",
        "config",
        "containers",
        "copy",
        "from",
        "images",
        "info",
        "inspect",
        "login",
        "logout",
        "pull",
        "push",
        "rename",
        "rm",
        "rmi",
        "run",
        "tag",
        "umount",
        "unmount",
        "version",
    },
}

FORBIDDEN_OPTIONS = {
    "--add-file",
    "--annotation",
    "--authfile",
    "--blkio-weight-device",
    "--build-context",
    "--cap-add",
    "--cap-drop",
    "--cert-dir",
    "--cgroup-conf",
    "--cgroup-parent",
    "--cgroups",
    "--cdi-spec-dir",
    "--chrootdirs",
    "--config",
    "--conmon",
    "--connection",
    "--cpp-flag",
    "--decryption-key",
    "--device",
    "--device-cgroup-rule",
    "--device-read-bps",
    "--device-read-iops",
    "--device-write-bps",
    "--device-write-iops",
    "--env-file",
    "--env-host",
    "--encryption-key",
    "--gidmap",
    "--group-add",
    "--groups",
    "--gpus",
    "--health-log-destination",
    "--hooks-dir",
    "--identity",
    "--imagestore",
    "--init-path",
    "--isolation",
    "--log-driver",
    "--log-opt",
    "--module",
    "--no-pivot",
    "--preserve-fd",
    "--preserve-fds",
    "--privileged",
    "--rdt-class",
    "--remote",
    "--root",
    "--rootfs",
    "--runroot",
    "--runtime",
    "--runtime-flag",
    "--seccomp-policy",
    "--secret",
    "--security-opt",
    "--ssh",
    "--storage-driver",
    "--storage-opt",
    "--subgidname",
    "--subuidname",
    "--tls-ca",
    "--tls-cert",
    "--tls-key",
    "--tmpdir",
    "--uidmap",
    "--url",
    "--userns-gid-map",
    "--userns-gid-map-group",
    "--userns-uid-map",
    "--userns-uid-map-user",
    "--volumes-from",
    "--volumepath",
}

HOST_NAMESPACE_OPTIONS = {
    "--cgroupns",
    "--ipc",
    "--network",
    "--net",
    "--pid",
    "--userns",
    "--uts",
}

PATH_OPTIONS = {
    "--build-arg-file": "path",
    "--cidfile": "path",
    "--conmon-pidfile": "path",
    "--contextdir": "path",
    "--digestfile": "path",
    "--file": "path",
    "-f": "path",
    "--hosts-file": "path",
    "--ignorefile": "path",
    "--iidfile": "path",
    "--iidfile-raw": "path",
    "--input": "path",
    "-i": "path",
    "--label-file": "path",
    "--logfile": "path",
    "--metadata-file": "path",
    "--mount": "mount",
    "--output": "output",
    "-o": "output",
    "--pidfile": "path",
    "--pod-id-file": "path",
    "--sbom-output": "path",
    "--sbom-purl-output": "path",
    "--source-policy-file": "path",
    "--sign-by-sigstore": "path",
    "--sign-by-sigstore-private-key": "path",
    "--sign-passphrase-file": "path",
    "--volume": "volume",
    "-v": "volume",
}

EXPLICIT_VALUE_OPTIONS = {
    "--build-arg",
    "--env",
    "-e",
}

SAFE_GLOBAL_VALUE_OPTIONS = {"--log-level"}
SAFE_GLOBAL_FLAGS = {"--help", "--version", "-v"}
REMOTE_CONTEXT_PREFIXES = (
    "container://",
    "docker://",
    "git://",
    "http://",
    "https://",
    "oci://",
)
COMPOSE_CONFIG_FLAGS = {"--quiet", "--services", "--volumes"}
COMPOSE_CONFIG_ENVIRONMENT = {
    "OPERCORD_DATABASE_URL_FILE",
    "OPERCORD_POSTGRES_PASSWORD",
    "OPERCORD_POSTGRES_PASSWORD_FILE",
    "OPERCORD_PUBLIC_BASE_URL",
    "OPERCORD_SESSION_SECRET_FILE",
    "OPERCORD_TLS_CERT_FILE",
    "OPERCORD_TLS_KEY_FILE",
}
COMPOSE_CONFIG_PATH_ENVIRONMENT = {
    "OPERCORD_DATABASE_URL_FILE",
    "OPERCORD_POSTGRES_PASSWORD_FILE",
    "OPERCORD_SESSION_SECRET_FILE",
    "OPERCORD_TLS_CERT_FILE",
    "OPERCORD_TLS_KEY_FILE",
}
COMPOSE_PROJECT_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9_.-]*")


def _profile_name(label: str) -> str:
    return label.strip().split(" (", 1)[0]


def _agent_for_profile(label: str) -> str:
    profile = _profile_name(label)
    agent = AGENTS_BY_PROFILE.get(profile)
    if agent is None or "(enforce)" not in label:
        raise GuardError("container commands must enter through an enforced agent broker profile")
    return agent


def _option(argument: str) -> tuple[str, str | None]:
    if argument.startswith("--") and "=" in argument:
        return tuple(argument.split("=", 1))  # type: ignore[return-value]
    return argument, None


def _inside_workspace(value: str, workspace: Path) -> Path:
    if not value or value == "-":
        raise GuardError("an empty or streamed host path is outside the guarded workspace contract")
    if value.startswith("~"):
        raise GuardError(f"host path must stay inside the workspace: {value}")
    candidate = Path(value)
    if not candidate.is_absolute():
        candidate = workspace / candidate
    resolved = candidate.resolve(strict=False)
    try:
        resolved.relative_to(workspace)
    except ValueError as error:
        raise GuardError(f"host path must stay inside the workspace: {value}") from error
    return resolved


def _validate_workspace(workspace: Path, home: Path) -> None:
    resolved_home = home.resolve(strict=True)
    try:
        relative = workspace.relative_to(resolved_home)
    except ValueError:
        relative = None
    if relative is not None:
        if relative.parts and not relative.parts[0].startswith("."):
            return
        raise GuardError("the current directory is not a scoped workspace")

    for temporary_root in (Path("/tmp"), Path("/var/tmp")):
        try:
            relative = workspace.relative_to(temporary_root)
        except ValueError:
            continue
        if relative.parts:
            return
    raise GuardError("the current directory is not a scoped workspace")


def _validate_volume(value: str, workspace: Path) -> None:
    source, separator, _destination = value.partition(":")
    if not separator or not source:
        return
    if source.startswith(("/", ".", "~")) or "/" in source:
        _inside_workspace(source, workspace)


def _validate_mount(value: str, workspace: Path) -> None:
    try:
        fields = next(csv.reader([value], skipinitialspace=True))
    except (csv.Error, StopIteration) as error:
        raise GuardError("invalid --mount value") from error
    values: dict[str, str] = {}
    for field in fields:
        key, separator, item = field.partition("=")
        if separator:
            values[key.strip().lower()] = item
    mount_type = values.get("type", "volume").lower()
    source = values.get("src") or values.get("source")
    if source is not None and (
        mount_type == "bind" or source.startswith(("/", ".", "~")) or "/" in source
    ):
        _inside_workspace(source, workspace)
    if mount_type == "bind" and source is None:
        raise GuardError("bind mounts require a workspace source")
    if mount_type not in {"bind", "tmpfs", "volume"}:
        raise GuardError(f"mount type {mount_type!r} is not permitted")


def _validate_output(value: str, workspace: Path) -> None:
    if "=" not in value:
        _inside_workspace(value, workspace)
        return
    try:
        fields = next(csv.reader([value], skipinitialspace=True))
    except (csv.Error, StopIteration) as error:
        raise GuardError("invalid --output value") from error
    values: dict[str, str] = {}
    for field in fields:
        key, separator, item = field.partition("=")
        if separator:
            values[key.strip().lower()] = item
    destination = values.get("dest") or values.get("destination")
    if destination is None:
        raise GuardError("structured output requires a workspace destination")
    _inside_workspace(destination, workspace)


def _validate_explicit_value(option: str, value: str) -> None:
    if "=" not in value:
        raise GuardError(f"{option} may not inherit a value from the host environment")


def _find_subcommand(arguments: Sequence[str]) -> tuple[str | None, int]:
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        option, inline = _option(argument)
        if not argument.startswith("-"):
            return argument, index
        if option in SAFE_GLOBAL_FLAGS and inline is None:
            index += 1
            continue
        if option in SAFE_GLOBAL_VALUE_OPTIONS:
            if inline is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"global option {option} requires a value")
            index += 1
            continue
        if option in FORBIDDEN_OPTIONS:
            raise GuardError(f"option {option} is not permitted")
        raise GuardError(f"global option {option} is not permitted")
    return None, len(arguments)


def _validate_named_podman_operation(
    group: str,
    arguments: Sequence[str],
    allowed_subcommands: set[str],
) -> str:
    if not arguments or arguments[0] not in allowed_subcommands:
        nested = arguments[0] if arguments else None
        raise GuardError(
            f"podman {group} subcommand {nested!r} is not permitted"
        )
    nested = arguments[0]
    names = arguments[1:]
    if not names:
        raise GuardError(f"podman {group} {nested} requires a name")
    for name in names:
        if not name or name.startswith("-"):
            raise GuardError(
                f"podman {group} {nested} argument {name!r} is not permitted"
            )
    return nested


def _validate_compose(arguments: Sequence[str], workspace: Path) -> str:
    index = 0
    while index < len(arguments):
        argument = arguments[index]
        option, inline = _option(argument)
        if option in {"--file", "-f"}:
            value = inline
            if value is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"podman compose option {option} requires a value")
                value = arguments[index]
            _inside_workspace(value, workspace)
        elif option in {"--project-name", "-p"}:
            value = inline
            if value is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"podman compose option {option} requires a value")
                value = arguments[index]
            if COMPOSE_PROJECT_RE.fullmatch(value) is None:
                raise GuardError(f"podman compose project {value!r} is not permitted")
        else:
            break
        index += 1

    if index >= len(arguments) or arguments[index] not in {"config", "version"}:
        nested = arguments[index] if index < len(arguments) else None
        raise GuardError(f"podman compose subcommand {nested!r} is not permitted")
    nested = arguments[index]
    remaining = arguments[index + 1 :]
    if nested == "version" and remaining:
        raise GuardError("podman compose version arguments are not permitted")
    if nested == "config":
        for argument in remaining:
            if argument not in COMPOSE_CONFIG_FLAGS:
                raise GuardError(
                    f"podman compose config argument {argument!r} is not permitted"
                )
    return nested


def _validate_arguments(
    tool: str, arguments: Sequence[str], workspace: Path
) -> bool:
    subcommand, command_index = _find_subcommand(arguments)
    if subcommand is None:
        return False

    compose_config = False
    if tool == "podman" and subcommand == "network":
        _validate_named_podman_operation(
            "network", arguments[command_index + 1 :], {"create", "rm"}
        )
    elif tool == "podman" and subcommand == "image":
        _validate_named_podman_operation(
            "image", arguments[command_index + 1 :], {"rm"}
        )
    elif tool == "podman" and subcommand == "compose":
        compose_config = (
            _validate_compose(arguments[command_index + 1 :], workspace) == "config"
        )
    elif subcommand not in ALLOWED_SUBCOMMANDS[tool]:
        raise GuardError(f"{tool} subcommand {subcommand!r} is not permitted")

    index = command_index + 1
    while index < len(arguments):
        argument = arguments[index]
        option, inline = _option(argument)

        if option in FORBIDDEN_OPTIONS:
            raise GuardError(f"option {option} is not permitted")

        if argument.startswith("-v") and len(argument) > 2 and inline is None:
            value = argument[2:].removeprefix("=")
            _validate_volume(value, workspace)
            index += 1
            continue

        if argument.startswith("-e") and len(argument) > 2 and inline is None:
            value = argument[2:].removeprefix("=")
            _validate_explicit_value("-e", value)
            index += 1
            continue

        if option in HOST_NAMESPACE_OPTIONS:
            value = inline
            if value is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"option {option} requires a value")
                value = arguments[index]
            if value in {"container", "host", "ns"} or value.startswith(
                ("/", ".", "~", "container:", "ns:")
            ):
                raise GuardError(f"option {option}={value} is not permitted")

        elif option in PATH_OPTIONS:
            value = inline
            if value is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"option {option} requires a value")
                value = arguments[index]
            kind = PATH_OPTIONS[option]
            if kind == "volume":
                _validate_volume(value, workspace)
            elif kind == "mount":
                _validate_mount(value, workspace)
            elif kind == "output":
                _validate_output(value, workspace)
            else:
                _inside_workspace(value, workspace)

        elif option in EXPLICIT_VALUE_OPTIONS:
            value = inline
            if value is None:
                index += 1
                if index >= len(arguments):
                    raise GuardError(f"option {option} requires a value")
                value = arguments[index]
            _validate_explicit_value(option, value)

        index += 1

    positional = [argument for argument in arguments[command_index + 1 :] if not argument.startswith("-")]
    if subcommand in {"build", "bud"} and positional:
        for context in positional:
            if context != "-" and not context.startswith(REMOTE_CONTEXT_PREFIXES):
                _inside_workspace(context, workspace)
    elif tool == "podman" and subcommand == "import" and positional:
        source = positional[0]
        if source != "-" and not source.startswith(REMOTE_CONTEXT_PREFIXES):
            _inside_workspace(source, workspace)
    elif tool == "podman" and subcommand == "cp":
        for endpoint in positional[:2]:
            if ":" not in endpoint:
                _inside_workspace(endpoint, workspace)
    elif tool == "buildah" and subcommand in {"add", "copy"} and len(positional) > 2:
        for source in positional[1:-1]:
            _inside_workspace(source, workspace)
    return compose_config


def _sanitized_environment(
    environment: Mapping[str, str],
    *,
    state: Path,
    runtime: Path,
    safe_path: str,
    containers_conf: str,
    storage_conf: str,
    workspace: Path,
    compose_config: bool,
) -> dict[str, str]:
    result = {
        key: value
        for key, value in environment.items()
        if key in {"COLORTERM", "LANG", "LANGUAGE", "NO_COLOR", "TERM", "TZ"}
        or key.startswith("LC_")
    }
    result.update(
        {
            "BUILDAH_ISOLATION": "oci",
            "CONTAINERS_CONF": containers_conf,
            "CONTAINERS_STORAGE_CONF": storage_conf,
            "HOME": str(state / "home"),
            "PATH": safe_path,
            "REGISTRY_AUTH_FILE": str(state / "auth.json"),
            "TMPDIR": str(runtime / "tmp"),
            "XDG_CACHE_HOME": str(state / "cache"),
            "XDG_CONFIG_HOME": str(state / "config"),
            "XDG_DATA_HOME": str(state / "data"),
            "XDG_RUNTIME_DIR": str(runtime),
        }
    )
    if compose_config:
        for name in COMPOSE_CONFIG_ENVIRONMENT:
            value = environment.get(name)
            if value is None:
                continue
            if name in COMPOSE_CONFIG_PATH_ENVIRONMENT:
                _inside_workspace(value, workspace)
            result[name] = value
    return result


def _ensure_private_auth_file(path: Path, *, uid: int) -> None:
    flags = os.O_WRONLY | os.O_CLOEXEC | os.O_NOFOLLOW
    created = False
    try:
        descriptor = os.open(path, flags | os.O_CREAT | os.O_EXCL, 0o600)
        created = True
    except FileExistsError:
        try:
            descriptor = os.open(path, flags)
        except OSError as error:
            raise GuardError("the isolated registry auth path is not a regular file") from error

    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode) or metadata.st_uid != uid:
            raise GuardError("the isolated registry auth file has an unsafe owner or type")
        if created:
            os.write(descriptor, b"{}")
        os.fchmod(descriptor, 0o600)
    finally:
        os.close(descriptor)


def _close_inherited_file_descriptors() -> None:
    try:
        descriptors = os.listdir("/proc/self/fd")
    except OSError as error:
        raise GuardError("cannot enumerate inherited file descriptors") from error

    for entry in descriptors:
        try:
            descriptor = int(entry)
        except ValueError:
            continue
        if descriptor <= 2:
            continue
        try:
            os.close(descriptor)
        except OSError as error:
            if error.errno != errno.EBADF:
                raise GuardError("cannot close an inherited file descriptor") from error


def build_invocation(
    tool: str,
    arguments: Sequence[str],
    environment: Mapping[str, str],
    cwd: Path,
    profile_label: str,
    *,
    uid: int,
    home: Path,
    executables: Mapping[str, str],
    safe_path: str,
    containers_conf: str,
    storage_conf: str,
) -> Invocation:
    if tool not in ALLOWED_SUBCOMMANDS or tool not in executables:
        raise GuardError(f"unsupported tool: {tool}")
    agent = _agent_for_profile(profile_label)
    workspace = cwd.resolve(strict=True)
    if not workspace.is_dir():
        raise GuardError("the current workspace is not a directory")
    _validate_workspace(workspace, home)
    compose_config = _validate_arguments(tool, arguments, workspace)

    state = home / ".local/share/containers/agents" / agent
    runtime = Path(f"/run/user/{uid}/agent-containers") / agent
    global_arguments = [
        "--root",
        str(state / "storage"),
        "--runroot",
        str(runtime / "storage"),
    ]
    if tool == "podman":
        global_arguments.extend(
            [
                "--tmpdir",
                str(runtime / "tmp"),
                "--events-backend=file",
                "--cgroup-manager=cgroupfs",
            ]
        )
    invocation_environment = _sanitized_environment(
        environment,
        state=state,
        runtime=runtime,
        safe_path=safe_path,
        containers_conf=containers_conf,
        storage_conf=storage_conf,
        workspace=workspace,
        compose_config=compose_config,
    )
    directories = (
        state,
        state / "home",
        state / "cache",
        state / "config",
        state / "data",
        state / "storage",
        runtime,
        runtime / "storage",
        runtime / "tmp",
    )
    return Invocation(
        argv=[executables[tool], *global_arguments, *arguments],
        environment=invocation_environment,
        directories=directories,
    )


def _current_profile() -> str:
    return Path("/proc/self/attr/current").read_text(encoding="utf-8").strip()


def main() -> int:
    if len(sys.argv) < 2:
        print("agent-container-guard: missing tool name", file=sys.stderr)
        return 126
    tool = sys.argv[1]
    user = pwd.getpwuid(os.getuid())
    try:
        invocation = build_invocation(
            tool,
            sys.argv[2:],
            os.environ,
            Path.cwd(),
            _current_profile(),
            uid=os.getuid(),
            home=Path(user.pw_dir),
            executables={
                "podman": "@podman@",
                "buildah": "@buildah@",
            },
            safe_path="@safe_path@",
            containers_conf="@containers_conf@",
            storage_conf="@storage_conf@",
        )
        _close_inherited_file_descriptors()
        for directory in invocation.directories:
            directory.mkdir(mode=0o700, parents=True, exist_ok=True)
            directory.chmod(0o700)
        _ensure_private_auth_file(
            Path(invocation.environment["REGISTRY_AUTH_FILE"]), uid=os.getuid()
        )
        os.execve(invocation.argv[0], invocation.argv, invocation.environment)
    except (GuardError, OSError) as error:
        print(f"agent-container-guard: {error}", file=sys.stderr)
        return 126
    return 126


if __name__ == "__main__":
    raise SystemExit(main())
