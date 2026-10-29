"""Presses niri's shortcut bind through the real xdg-desktop-portal frontend.

Run inside a private session bus whose service directories include the shortcuts
portal, with the host's portal configuration and XDG_DESKTOP_PORTAL_DIR set.
"""

import asyncio
import json
import os
import subprocess
import unittest
from itertools import count

from dbus_fast import Message, MessageType, Variant
from dbus_fast.aio import MessageBus


BIND = json.loads(os.environ["NIRI_BIND_COMMAND"])
APP_ID, SHORTCUT_ID = BIND[-2:]
DESKTOP = "org.freedesktop.portal.Desktop"
DESKTOP_PATH = "/org/freedesktop/portal/desktop"
SHORTCUTS = "org.freedesktop.portal.GlobalShortcuts"
tokens = count()


async def bus_call(bus, destination, path, interface, member, signature="", body=()):
    reply = await bus.call(Message(
        destination=destination, path=path, interface=interface,
        member=member, signature=signature, body=list(body),
    ))
    if reply.message_type == MessageType.ERROR:
        raise RuntimeError(f"{member}: {reply.error_name}: {reply.body}")
    return reply.body


class Application:
    """Binds a shortcut through the portal the way Ghostty does."""

    def __init__(self, bus):
        self.bus = bus
        self.responses = {}
        self.activations = asyncio.Queue()
        bus.add_message_handler(self.handle)

    @classmethod
    async def connect(cls):
        bus = await MessageBus().connect()
        for rule in (
            "type='signal',interface='org.freedesktop.portal.Request',member='Response'",
            f"type='signal',interface='{SHORTCUTS}',member='Activated'",
        ):
            await bus_call(
                bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "AddMatch", "s", [rule],
            )
        return cls(bus)

    def handle(self, message):
        if message.message_type != MessageType.SIGNAL:
            return
        if message.member == "Response" and message.path in self.responses:
            self.responses.pop(message.path).set_result(message.body)
        elif message.interface == SHORTCUTS and message.member == "Activated":
            self.activations.put_nowait(tuple(message.body[:2]))

    async def request(self, member, signature, body, options=None):
        token = f"test{next(tokens)}"
        sender = self.bus.unique_name[1:].replace(".", "_")
        response = asyncio.get_running_loop().create_future()
        # The portal can respond before the call returns, so listen first.
        self.responses[f"{DESKTOP_PATH}/request/{sender}/{token}"] = response
        options = {**(options or {}), "handle_token": Variant("s", token)}
        await bus_call(self.bus, DESKTOP, DESKTOP_PATH, SHORTCUTS, member, signature, [*body, options])
        code, results = await asyncio.wait_for(response, 5)
        if code != 0:
            raise RuntimeError(f"{member} responded {code}")
        return results

    async def bind(self):
        await bus_call(
            self.bus, DESKTOP, DESKTOP_PATH, "org.freedesktop.host.portal.Registry",
            "Register", "sa{sv}", [APP_ID, {}],
        )
        results = await self.request(
            "CreateSession", "a{sv}", [],
            {"session_handle_token": Variant("s", f"session{next(tokens)}")},
        )
        session = results["session_handle"].value
        shortcut = [SHORTCUT_ID, {
            "description": Variant("s", "toggle_quick_terminal"),
            "preferred_trigger": Variant("s", SHORTCUT_ID),
        }]
        results = await self.request("BindShortcuts", "oa(sa{sv})sa{sv}", [session, [shortcut], ""])
        bound = [shortcut_id for shortcut_id, _ in results["shortcuts"].value]
        if bound != [SHORTCUT_ID]:
            raise RuntimeError(f"bound {bound}")
        return session


async def press():
    process = await asyncio.create_subprocess_exec(
        *BIND, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    _, stderr = await process.communicate()
    return process.returncode, stderr.decode()


class ShortcutsPortalTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.bus = await MessageBus().connect()
        await self.start_frontend()

    async def asyncTearDown(self):
        self.stop_frontend()
        self.bus.disconnect()

    async def start_frontend(self):
        self.frontend = subprocess.Popen([os.environ["XDG_DESKTOP_PORTAL"]])
        for _ in range(100):
            [owned] = await bus_call(
                self.bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
                "org.freedesktop.DBus", "NameHasOwner", "s", [DESKTOP],
            )
            if owned:
                return
            await asyncio.sleep(0.1)
        raise TimeoutError("xdg-desktop-portal did not start")

    def stop_frontend(self):
        self.frontend.terminate()
        self.frontend.wait(timeout=5)

    async def test_bind_activates_the_bound_shortcut(self):
        application = await Application.connect()
        session = await application.bind()

        self.assertEqual(await press(), (0, ""))
        self.assertEqual(
            await asyncio.wait_for(application.activations.get(), 5), (session, SHORTCUT_ID)
        )

    async def test_restarted_frontend_requires_binding_again(self):
        application = await Application.connect()
        await application.bind()
        self.stop_frontend()
        await self.start_frontend()

        code, stderr = await press()
        self.assertNotEqual(code, 0)
        self.assertIn(f"{APP_ID} has not bound {SHORTCUT_ID}", stderr)

        session = await application.bind()
        self.assertEqual(await press(), (0, ""))
        self.assertEqual(
            await asyncio.wait_for(application.activations.get(), 5), (session, SHORTCUT_ID)
        )

    async def test_exited_application_is_forgotten(self):
        application = await Application.connect()
        await application.bind()
        application.bus.disconnect()
        await application.bus.wait_for_disconnect()

        for _ in range(50):
            code, stderr = await press()
            if code != 0:
                break
            await asyncio.sleep(0.1)
        self.assertIn(f"{APP_ID} has not bound {SHORTCUT_ID}", stderr)


if __name__ == "__main__":
    unittest.main()
