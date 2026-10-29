"""GlobalShortcuts portal backend whose shortcuts are pressed by compositor key bindings.

Niri does not implement the GlobalShortcuts portal. Applications bind their shortcuts
here through xdg-desktop-portal, and a niri bind calls Activate to press one of them.
"""

import asyncio
import logging
import time

from dbus_fast import BusType, DBusError, ErrorType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.constants import NameFlag, RequestNameReply
from dbus_fast.service import (
    PropertyAccess,
    ServiceInterface,
    dbus_method,
    dbus_property,
    dbus_signal,
)

BUS_NAME = "@bus_name@"
PORTAL_PATH = "/org/freedesktop/portal/desktop"
FRONTEND_NAME = "org.freedesktop.portal.Desktop"


class Session(ServiceInterface):
    def __init__(self, portal, path, app_id):
        super().__init__("org.freedesktop.impl.portal.Session")
        self.portal = portal
        self.path = path
        self.app_id = app_id
        self.shortcuts = {}

    @dbus_method()
    def Close(self):
        self.portal.close_session(self)


class GlobalShortcuts(ServiceInterface):
    def __init__(self, bus):
        super().__init__("org.freedesktop.impl.portal.GlobalShortcuts")
        self.bus = bus
        self.sessions = {}

    def close_session(self, session):
        self.bus.unexport(session.path, session)
        del self.sessions[session.path]

    def find_session(self, path):
        session = self.sessions.get(path)
        if session is None:
            raise DBusError(ErrorType.ACCESS_DENIED, f"Unknown session {path}")
        return session

    @staticmethod
    def describe(session):
        return Variant("a(sa{sv})", [
            [shortcut_id, {"description": Variant("s", description)}]
            for shortcut_id, description in session.shortcuts.items()
        ])

    @dbus_method()
    def CreateSession(
        self, handle: "o", session_handle: "o", app_id: "s", options: "a{sv}"
    ) -> "ua{sv}":
        session = Session(self, session_handle, app_id)
        self.bus.export(session_handle, session)
        self.sessions[session_handle] = session
        return 0, {}

    @dbus_method()
    def BindShortcuts(
        self, handle: "o", session_handle: "o", shortcuts: "a(sa{sv})",
        parent_window: "s", options: "a{sv}",
    ) -> "ua{sv}":
        session = self.find_session(session_handle)
        session.shortcuts = {
            shortcut_id: values["description"].value if "description" in values else ""
            for shortcut_id, values in shortcuts
        }
        logging.info("%s bound %s", session.app_id, ", ".join(session.shortcuts) or "nothing")
        return 0, {"shortcuts": self.describe(session)}

    @dbus_method()
    def ListShortcuts(self, handle: "o", session_handle: "o") -> "ua{sv}":
        return 0, {"shortcuts": self.describe(self.find_session(session_handle))}

    @dbus_signal()
    def Activated(self, session_handle, shortcut_id, timestamp) -> "osta{sv}":
        return session_handle, shortcut_id, timestamp, {}

    @dbus_signal()
    def Deactivated(self, session_handle, shortcut_id, timestamp) -> "osta{sv}":
        return session_handle, shortcut_id, timestamp, {}

    @dbus_property(access=PropertyAccess.READ)
    def version(self) -> "u":
        return 1

    def frontend_changed(self, name, old_owner, new_owner):
        # Sessions live in the frontend, so a restarted frontend has none of them.
        if name != FRONTEND_NAME or not old_owner:
            return
        for session in list(self.sessions.values()):
            self.close_session(session)


class Bindings(ServiceInterface):
    def __init__(self, portal):
        super().__init__(BUS_NAME)
        self.portal = portal

    @dbus_method()
    def Activate(self, app_id: "s", shortcut_id: "s"):
        sessions = [
            session for session in self.portal.sessions.values()
            if session.app_id == app_id and shortcut_id in session.shortcuts
        ]
        if not sessions:
            logging.warning("%s has not bound %s", app_id, shortcut_id)
            raise DBusError(ErrorType.FAILED, f"{app_id} has not bound {shortcut_id}")

        timestamp = time.monotonic_ns() // 1_000_000
        for session in sessions:
            self.portal.Activated(session.path, shortcut_id, timestamp)
            self.portal.Deactivated(session.path, shortcut_id, timestamp)


async def main():
    logging.basicConfig(level=logging.INFO, format="%(message)s")
    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    portal = GlobalShortcuts(bus)
    bus.export(PORTAL_PATH, portal)
    bus.export(PORTAL_PATH, Bindings(portal))

    introspection = await bus.introspect("org.freedesktop.DBus", "/org/freedesktop/DBus")
    daemon = bus.get_proxy_object("org.freedesktop.DBus", "/org/freedesktop/DBus", introspection)
    daemon.get_interface("org.freedesktop.DBus").on_name_owner_changed(portal.frontend_changed)

    reply = await bus.request_name(BUS_NAME, NameFlag.DO_NOT_QUEUE)
    if reply != RequestNameReply.PRIMARY_OWNER:
        raise RuntimeError(f"{BUS_NAME} is already owned")
    try:
        await bus.wait_for_disconnect()
    except EOFError:
        # The session bus closed, which ends the graphical session's services.
        pass


if __name__ == "__main__":
    asyncio.run(main())
