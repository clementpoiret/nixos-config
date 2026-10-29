from concurrent.futures import ThreadPoolExecutor
from copy import deepcopy
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import socket
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).parent.parent
source = os.environ.get(
    "NIRI_SCRATCH_TERMINAL_SOURCE", str(ROOT / "modules/home/niri-scratch-terminal.py")
)
spec = importlib.util.spec_from_file_location("scratch_terminal", source)
terminal = importlib.util.module_from_spec(spec)
spec.loader.exec_module(terminal)
APP_ID = "com.mitchellh.ghostty.scratchpad"
GHOSTTY = "/test/ghostty"


class NiriSession:
    def __init__(self):
        self.workspaces = [
            self.workspace(101, 1, "eDP-1", focused=True, window=10),
            self.workspace(102, 2, "eDP-1"),
            self.workspace(201, 1, "DP-1"),
            self.workspace(202, 2, "DP-1"),
        ]
        self.windows = [{"id": 10, "app_id": "com.mitchellh.ghostty", "workspace_id": 101}]
        self.spawned = []
        self.actions = []
        self.pending = None

    @staticmethod
    def workspace(id, index, output, focused=False, window=None, name=None):
        return {
            "id": id, "idx": index, "name": name, "output": output,
            "is_focused": focused, "active_window_id": window,
        }

    def focus_workspace(self, id):
        for workspace in self.workspaces:
            workspace["is_focused"] = workspace["id"] == id

    def request(self, message):
        if message == "Windows":
            if self.pending is not None:
                self.windows.append(self.pending)
                self.pending = None
            return {"Windows": deepcopy(self.windows)}
        if message == "Workspaces":
            return {"Workspaces": deepcopy(self.workspaces)}

        name, args = next(iter(message["Action"].items()))
        self.actions.append((name, args))
        if name == "Spawn":
            self.spawned.append(args["command"])
            focused = next(workspace for workspace in self.workspaces if workspace["is_focused"])
            self.pending = {
                "id": 42, "app_id": APP_ID, "workspace_id": focused["id"], "is_floating": True,
            }
        elif name == "MoveWindowToWorkspace":
            window = next(window for window in self.windows if window["id"] == args["window_id"])
            window["workspace_id"] = args["reference"]["Id"]
            if args["focus"]:
                self.focus_workspace(window["workspace_id"])
        elif name == "MoveWindowToFloating":
            next(window for window in self.windows if window["id"] == args["id"])["is_floating"] = True
        elif name == "FocusWindow":
            window = next(window for window in self.windows if window["id"] == args["id"])
            self.focus_workspace(window["workspace_id"])
        else:
            raise AssertionError(f"Unexpected action: {name}")
        return "Handled"


class ScratchTerminalTests(unittest.TestCase):
    def setUp(self):
        self.session = NiriSession()
        self.request = patch.object(terminal, "request", side_effect=self.session.request)
        self.request.start()
        self.addCleanup(self.request.stop)

    def toggle(self):
        terminal.toggle(APP_ID, GHOSTTY)

    def test_reuses_the_same_terminal_without_moving_regular_windows_or_focus(self):
        self.toggle()
        self.assertEqual(self.session.spawned, [
            [GHOSTTY, f"--class={APP_ID}", "--initial-window=true"]
        ])
        scratch = self.session.windows[-1]
        self.assertEqual(scratch["workspace_id"], 101)

        self.toggle()
        self.assertEqual(scratch["workspace_id"], 102)
        self.assertTrue(self.session.workspaces[0]["is_focused"])
        self.assertEqual(self.session.windows[0]["workspace_id"], 101)

        scratch["is_floating"] = False
        self.toggle()
        self.assertEqual(scratch["workspace_id"], 101)
        self.assertTrue(scratch["is_floating"])
        self.assertEqual(len(self.session.spawned), 1)
        self.assertEqual(self.session.actions[-1], ("FocusWindow", {"id": 42}))

    def test_summons_across_monitors_using_workspace_ids(self):
        self.toggle()
        self.toggle()
        self.session.focus_workspace(201)
        self.toggle()
        self.assertEqual(self.session.windows[-1]["workspace_id"], 201)
        self.toggle()
        self.assertEqual(self.session.windows[-1]["workspace_id"], 202)
        self.assertTrue(self.session.workspaces[2]["is_focused"])
        self.assertEqual(len(self.session.spawned), 1)

    def test_parking_does_not_use_named_or_occupied_workspaces(self):
        self.toggle()
        self.session.workspaces.extend([
            self.session.workspace(103, 3, "eDP-1", name="chat"),
            self.session.workspace(104, 4, "eDP-1", window=99),
            self.session.workspace(105, 5, "eDP-1"),
        ])
        self.toggle()
        self.assertEqual(self.session.windows[-1]["workspace_id"], 105)

    def test_recreates_a_closed_terminal(self):
        self.toggle()
        self.session.windows.pop()
        self.toggle()
        self.assertEqual(len(self.session.spawned), 2)
        self.assertEqual(self.session.windows[-1]["workspace_id"], 101)

    def test_reports_a_failed_launch(self):
        with patch.object(terminal.time, "monotonic", side_effect=[0, 11]):
            with self.assertRaisesRegex(TimeoutError, "did not open"):
                self.toggle()


class ScratchTerminalIpcTests(unittest.TestCase):
    def test_reads_successful_replies_and_reports_compositor_errors(self):
        for reply in ({"Ok": {"Version": "26.04"}}, {"Err": "compositor rejected request"}):
            with self.subTest(reply=reply), tempfile.TemporaryDirectory() as directory:
                path = str(Path(directory) / "niri.sock")
                with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                    server.bind(path)
                    server.listen(1)
                    server.settimeout(5)

                    def respond():
                        client, _ = server.accept()
                        with client, client.makefile("r") as stream:
                            message = json.loads(stream.readline())
                            client.sendall((json.dumps(reply) + "\n").encode())
                            return message

                    with ThreadPoolExecutor(max_workers=1) as executor:
                        response = executor.submit(respond)
                        with patch.dict(os.environ, NIRI_SOCKET=path):
                            if "Err" in reply:
                                with self.assertRaisesRegex(RuntimeError, "compositor rejected"):
                                    terminal.request("Version")
                            else:
                                self.assertEqual(terminal.request("Version"), reply["Ok"])
                        self.assertEqual(response.result(timeout=5), "Version")

    def test_ignores_overlapping_toggles_and_releases_the_lock(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(os.environ, XDG_RUNTIME_DIR=directory), \
                 patch.object(terminal.sys, "argv", [source, APP_ID, GHOSTTY]), \
                 patch.object(terminal, "toggle") as toggle:
                with (Path(directory) / "niri-scratch-terminal.lock").open("a") as lock:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    terminal.main()
                    toggle.assert_not_called()
                terminal.main()
                toggle.assert_called_once_with(APP_ID, GHOSTTY)


if __name__ == "__main__":
    unittest.main()
