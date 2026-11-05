"""Exercise daemon restart ordering with deliberately slow descriptor cleanup."""

import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import time
import unittest


BINARY = sys.argv.pop(1)


class RestartTest(unittest.TestCase):
    def test_restart_releases_the_lock_before_closing_clients(self):
        with tempfile.TemporaryDirectory(prefix="hc-restart-") as temporary:
            root = Path(temporary)
            env = {
                "PATH": os.environ["PATH"],
                "HOME": str(root),
                "HC_SESSION": "test",
                "XDG_RUNTIME_DIR": str(root / "run"),
                "XDG_STATE_HOME": str(root / "state"),
                "XDG_CONFIG_HOME": str(root / "config"),
            }
            for name in ("run", "state", "config"):
                (root / name).mkdir()

            def command(*args):
                return subprocess.run(
                    [BINARY, "--json", *args], env=env, capture_output=True, text=True, timeout=15
                )

            with (root / "serve.log").open("w+") as log:
                server = subprocess.Popen(
                    [
                        "strace",
                        "--quiet",
                        "--follow-forks",
                        "--output",
                        str(root / "trace"),
                        "--trace=close",
                        "--inject=close:delay_enter=50ms",
                        BINARY,
                        "serve",
                    ],
                    env=env,
                    stdout=subprocess.DEVNULL,
                    stderr=log,
                    start_new_session=True,
                )
                try:
                    endpoint = root / "run/herdr-core/test.sock"
                    deadline = time.monotonic() + 10
                    while True:
                        self.assertIsNone(server.poll(), "traced server exited before listening")
                        with socket.socket(socket.AF_UNIX) as connection:
                            try:
                                connection.connect(str(endpoint))
                                break
                            except (FileNotFoundError, ConnectionRefusedError):
                                self.assertLess(time.monotonic(), deadline, "server did not listen")
                                time.sleep(0.01)

                    before = command("server", "status")
                    self.assertEqual(before.returncode, 0, before.stderr)
                    restarted = command("server", "restart")
                    self.assertEqual(restarted.returncode, 0, restarted.stderr)
                    self.assertNotEqual(json.loads(before.stdout)["pid"], json.loads(restarted.stdout)["pid"])
                    self.assertEqual(server.wait(timeout=10), 0)
                finally:
                    if server.poll() is None:
                        os.killpg(server.pid, signal.SIGTERM)
                        try:
                            server.wait(timeout=10)
                        except subprocess.TimeoutExpired:
                            os.killpg(server.pid, signal.SIGKILL)
                            server.wait()
                    stopped = command("server", "stop")
                    self.assertEqual(stopped.returncode, 0, stopped.stderr)


if __name__ == "__main__":
    unittest.main()
