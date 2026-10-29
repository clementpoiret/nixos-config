import fcntl
import json
import os
from pathlib import Path
import socket
import sys
import time


def request(message):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(5)
        client.connect(os.environ["NIRI_SOCKET"])
        client.sendall((json.dumps(message) + "\n").encode())
        with client.makefile("r") as response:
            reply = json.loads(response.readline())
    if "Err" in reply:
        raise RuntimeError(reply["Err"])
    return reply["Ok"]


def action(name, **arguments):
    request({"Action": {name: arguments}})


def find_terminal(app_id):
    return next(
        (window for window in request("Windows")["Windows"] if window["app_id"] == app_id),
        None,
    )


def toggle(app_id, ghostty):
    terminal = find_terminal(app_id)
    if terminal is None:
        action("Spawn", command=[ghostty, f"--class={app_id}", "--initial-window=true"])
        # Hold the launch lock until the compositor can see the new window.
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if find_terminal(app_id) is not None:
                return
            time.sleep(0.05)
        raise TimeoutError("Ghostty did not open a scratch terminal within 10 seconds")

    workspaces = request("Workspaces")["Workspaces"]
    focused = next((workspace for workspace in workspaces if workspace["is_focused"]), None)
    if focused is None:
        raise RuntimeError("Niri has no focused workspace")

    if terminal["workspace_id"] == focused["id"]:
        empty = [
            workspace for workspace in workspaces
            if workspace["output"] == focused["output"]
            and workspace["id"] != focused["id"]
            and workspace["name"] is None
            and workspace["active_window_id"] is None
        ]
        if not empty:
            raise RuntimeError("Niri has no empty workspace for parking the scratch terminal")
        parking = max(empty, key=lambda workspace: workspace["idx"])
        action(
            "MoveWindowToWorkspace", window_id=terminal["id"],
            reference={"Id": parking["id"]}, focus=False,
        )
        return

    # Workspace indices are per-monitor; IDs also work when summoning across outputs.
    action(
        "MoveWindowToWorkspace", window_id=terminal["id"],
        reference={"Id": focused["id"]}, focus=False,
    )
    action("MoveWindowToFloating", id=terminal["id"])
    action("FocusWindow", id=terminal["id"])


def main():
    lock_path = Path(os.environ["XDG_RUNTIME_DIR"]) / "niri-scratch-terminal.lock"
    with lock_path.open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        toggle(*sys.argv[1:])


if __name__ == "__main__":
    main()
