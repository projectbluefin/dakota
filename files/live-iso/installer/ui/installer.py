#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GObject, Gio, GLib
import dbus
import dbus.mainloop.glib
import sys
import os
import gettext
import locale

gettext.install('org.gnome.Installer')
locale.textdomain('org.gnome.Installer')


gresource = Gio.Resource.load(os.path.join(os.path.dirname(os.path.abspath(__file__)), 'org.gnome.Installer.gresource'))
Gio.Resource._register(gresource)


def human_readable_size(size):
    for suffix in ["B", "KB", "MB", "GB", "TB"]:
        if size < 10 and suffix != "B":
            return f"{size:.1f}{suffix}"
        if size < 1024 or suffix == "TB":
            r = round(size)
            return f"{r}{suffix}"
        size /= 1024


BUS = 'org.gnome.Installer1'
# Long enough to read where the install goes next.
HAND_OVER_AFTER_SECONDS = 7


def error_text(error):
    """What a failed call to the daemon says, without the D-Bus error name."""
    return error.get_dbus_message() or str(error)


class Installer:
    """The install daemon, which does everything that needs privileges."""

    def __init__(self, on_finished, on_error, on_stopped):
        self._on_finished = on_finished
        self._on_error = on_error
        self.system_bus = dbus.SystemBus()
        # The daemon is restarted if it fails, and comes back under a new
        # bus address; follow the name.
        obj = self.system_bus.get_object(BUS, '/org/gnome/Installer', follow_name_owner_changes=True)
        self._installer = dbus.Interface(obj, dbus_interface=BUS)
        self._installer.connect_to_signal('InstallationFinished', self._installation_finished)
        self._installer.connect_to_signal('InstallationFailed', self._installation_failed)
        self._installer.connect_to_signal('Progress', self._progress)
        self.system_bus.watch_name_owner(BUS, lambda owner: owner or on_stopped())
        self.on_progress = None
        self.encrypt = True
        self.secure_boot = True

    def encryption_blocker(self):
        return str(self._installer.GetEncryptionBlocker())

    def disks(self):
        return [(str(name), str(ident), str(model), str(transport), int(size), bool(has_data), str(problem))
                for name, ident, model, transport, size, has_data, problem in self._installer.GetDisks()]

    def install(self, name, ident):
        options = {'encrypt': dbus.Boolean(self.encrypt),
                   'secure-boot': dbus.Boolean(self.secure_boot)}
        self._installer.Install(name, ident, dbus.Dictionary(options, signature='sv'))

    def secure_boot_state(self):
        enabled, enrolled = self._installer.GetSecureBootState()
        return bool(enabled), bool(enrolled)

    def restart(self):
        self._installer.Restart()

    def status(self):
        state, step, fraction, key, mok, message = self._installer.GetStatus()
        return str(state), str(step), float(fraction), str(key), bool(mok), str(message)

    def hand_over(self):
        self._installer.HandOver()

    def acknowledge(self):
        self._installer.Acknowledge()

    def _progress(self, step, fraction):
        if self.on_progress:
            self.on_progress(str(step), float(fraction))

    def _installation_finished(self):
        self._on_finished()

    def _installation_failed(self, message, can_retry):
        self._on_error(str(message), bool(can_retry))


@Gtk.Template(resource_path="/org/gnome/os/proto-installer/erase-disk.ui")
class EraseDiskAlertDialog(Adw.AlertDialog):
    """Asked before every install, with the disk named: it is about to be erased."""
    __gtype_name__ = "EraseDiskAlertDialog"

    def onResponse(self, source, result):
        if self.choose_finish(result) == "erase":
            self._app.start_install(self._row)

    def __init__(self, parent, app, row):
        super().__init__()
        self._app = app
        self._row = row
        body = _("Installing Bluefin erases everything on {disk}.").format(disk=row.describe())
        if row.has_data():
            body = _("This disk contains data.") + " " + body
        if not app.installer.encrypt:
            body += " " + _("The new system will not be encrypted.")
        self.set_body(body)
        self.choose(parent, None, self.onResponse)


@Gtk.Template(resource_path="/org/gnome/os/proto-installer/install-button.ui")
class InstallButton(Gtk.Button):
    __gtype_name__ = "InstallButton"

    @Gtk.Template.Callback()
    def doInstall(self, *args):
        EraseDiskAlertDialog(self, self._app, self._selector.DiskList.get_selected_row())

    def __init__(self, app, selector):
        super().__init__()
        self._app = app
        self._selector = selector

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/install-or-live.ui")
class InstallOrLive(Adw.NavigationPage):
    __gtype_name__ = "InstallOrLive"

    StatusPage = Gtk.Template.Child()

    @Gtk.Template.Callback()
    def clicked_install(self, *args):
        self._on_install()

    @Gtk.Template.Callback()
    def clicked_try(self, *args):
        self._on_try()

    def __init__(self, on_try, on_install):
        super().__init__()
        self._on_try = on_try
        self._on_install = on_install

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/disk-selector.ui")
class DiskSelector(Adw.NavigationPage):
    __gtype_name__ = "DiskSelector"

    DiskList = Gtk.Template.Child()
    EncryptionRow = Gtk.Template.Child()
    SecureBootRow = Gtk.Template.Child()

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/status-display.ui")
class StatusDisplay(Adw.NavigationPage):
    __gtype_name__ = "StatusDisplay"

    StatusPage = Gtk.Template.Child()
    ProgressBox = Gtk.Template.Child()
    Progress = Gtk.Template.Child()
    StepLabel = Gtk.Template.Child()
    RecoveryKey = Gtk.Template.Child()
    RecoveryKeyDisplay = Gtk.Template.Child()
    CopyKey = Gtk.Template.Child()
    SecureBootNote = Gtk.Template.Child()
    SecureBootNoteRow = Gtk.Template.Child()
    FinishButtons = Gtk.Template.Child()

    @Gtk.Template.Callback()
    def clicked_keep(self, *args):
        try:
            self._app.installer.acknowledge()
        except dbus.DBusException as error:
            self._app.alert(_("The Installer Did Not Answer"), error_text(error))
            return
        self._app.quit()

    @Gtk.Template.Callback()
    def clicked_restart(self, *args):
        try:
            self._app.installer.restart()
        except dbus.DBusException as error:
            self._app.alert(_("The Installer Did Not Answer"), error_text(error))

    @Gtk.Template.Callback()
    def clicked_copy_key(self, *args):
        self.get_clipboard().set(self.RecoveryKey.get_label())
        self.CopyKey.set_icon_name("object-select-symbolic")
        self.CopyKey.set_tooltip_text(_("Copied"))
        GLib.timeout_add_seconds(2, self._reset_copy_key)

    def _reset_copy_key(self):
        self.CopyKey.set_icon_name("edit-copy-symbolic")
        self.CopyKey.set_tooltip_text(_("Copy"))
        return False

    def __init__(self, app):
        super().__init__()
        self._app = app

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/installer-window.ui")
class InstallerWindow(Adw.ApplicationWindow):
    __gtype_name__ = "InstallerWindow"

    Header = Gtk.Template.Child()
    ToolbarView = Gtk.Template.Child()
    NavigationView = Gtk.Template.Child()

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/disk-row.ui")
class DiskRow(Adw.ActionRow):
    __gtype_name__ = "DiskRow"

    def __init__(self, name, ident, model, transport, size, has_data, problem):
        super().__init__()
        self._name = name
        self._ident = ident
        self._model = model or _("Disk")
        self._size = size
        self._has_data = has_data
        self.set_title(self._model)
        self.set_subtitle(f"{human_readable_size(size)} · {name}")
        if problem:
            self.set_selectable(False)
            self.add_suffix(ErrorIcon(GLib.markup_escape_text(problem)))
        elif has_data:
            self.add_suffix(WarningIcon(_("<b>This disk contains data.</b>")))
        icon = 'drive-harddisk-usb-symbolic' if transport == 'usb' else 'drive-harddisk-symbolic'
        self.add_prefix(Gtk.Image.new_from_icon_name(icon))

    def get_device_name(self):
        return self._name

    def get_ident(self):
        return self._ident

    def has_data(self):
        return self._has_data

    def describe(self):
        return f"{self._model} ({human_readable_size(self._size)}, {self._name})"

@Gtk.Template(resource_path="/org/gnome/os/proto-installer/warning-icon.ui")
class WarningIcon(Gtk.Box):
    __gtype_name__ = "WarningIcon"

    WarningLabel = Gtk.Template.Child()

    def __init__(self, text):
        super().__init__()
        self.WarningLabel.set_markup(text)


@Gtk.Template(resource_path="/org/gnome/os/proto-installer/error-icon.ui")
class ErrorIcon(Gtk.Box):
    __gtype_name__ = "ErrorIcon"

    ErrorLabel = Gtk.Template.Child()

    def __init__(self, text):
        super().__init__()
        self.ErrorLabel.set_markup(text)


class InstallerApp(Adw.Application):
    def __init__(self, mainloop, **kwargs):
        super().__init__(**kwargs)
        self.connect('activate', self.on_activate)
        self.install_action = Gio.SimpleAction.new('install', None)
        self.install_action.connect('activate', self.on_activate_installer)
        self.add_action(self.install_action)
        self.mainloop = mainloop
        self._status_content = None
        self._handed_over = True
        self._done = False

    def _on_finished(self):
        self._done = True
        state, step, fraction, key, mok_queued, warning = self.installer.status()
        page = self._status_content
        page.ProgressBox.set_visible(False)
        page.StatusPage.set_icon_name("object-select-symbolic")
        page.StatusPage.set_title(_("Bluefin Is Installed"))
        page.StatusPage.set_description(_("You are running from your disk now. You can remove the install media."))
        # No key: the disk is not encrypted.
        page.RecoveryKey.set_label(key)
        page.RecoveryKeyDisplay.set_visible(bool(key))
        if mok_queued:
            page.SecureBootNoteRow.set_subtitle(_("On the next restart choose \"Enroll MOK\", then Continue, then Yes, and enter the password: dakota"))
            page.SecureBootNote.set_visible(True)
        elif warning:
            page.SecureBootNoteRow.set_title(_("Secure Boot is not set up"))
            page.SecureBootNoteRow.set_subtitle(warning)
            page.SecureBootNote.set_visible(True)
        page.FinishButtons.set_visible(True)

    def _on_error(self, message, can_retry=False):
        if can_retry:
            # Nothing was moved: back to the disk list, with the reason.
            self.win.NavigationView.pop_to_page(self._disk_selector)
            self._status_content = None
            self.win.Header.pack_end(self._install_button)
            self._load_disks()
            self.alert(_("Installation Could Not Start"), message)
            return
        self._done = True
        page = self._status_content
        page.ProgressBox.set_visible(False)
        page.RecoveryKeyDisplay.set_visible(False)
        page.StatusPage.set_icon_name("computer-fail-symbolic")
        page.StatusPage.set_title(_("Installation Failed"))
        page.StatusPage.set_description(message)

    def _on_stopped(self):
        # The daemon went away. It is restarted and reports what became of
        # the install; show that when it is back.
        if self._status_content is None or self._done:
            return
        GLib.timeout_add_seconds(3, self._after_restart)

    def _after_restart(self):
        try:
            state, step, fraction, key, mok_queued, message = self.installer.status()
        except dbus.DBusException as error:
            state, message = 'failed', error_text(error)
        if state == 'finished':
            self._on_finished()
        elif state != 'installing':
            self._on_error(message or _("The installer stopped unexpectedly."))
        return False

    def alert(self, heading, body):
        dialog = Adw.AlertDialog(heading=heading, body=body)
        dialog.add_response("close", _("Close"))
        dialog.present(self.win)

    def _on_progress(self, step, fraction):
        if self._status_content is None:
            return
        self._status_content.Progress.set_fraction(fraction)
        self._status_content.StepLabel.set_label(step)
        self._maybe_hand_over()

    def _maybe_hand_over(self):
        """Hand over to account setup once the session is moving to the disk.

        Not earlier: until then the install can still fail and be tried
        again, and the user has to be here for that.
        """
        if self._handed_over or GLib.get_monotonic_time() < self._hand_over_from:
            return False
        if self.installer.status()[0] != 'installing':
            return False
        self._handed_over = True
        self.installer.hand_over()
        return False

    def start_install(self, row):
        try:
            self.installer.install(row.get_device_name(), row.get_ident())
        except dbus.DBusException as error:
            self._load_disks()
            self.alert(_("Installation Could Not Start"), error_text(error))
            return
        self.win.Header.remove(self._install_button)
        self._status_content = StatusDisplay(self)
        self.installer.on_progress = self._on_progress
        page = self._status_content
        page.RecoveryKeyDisplay.set_visible(False)
        page.StatusPage.set_title(_("Installing Bluefin"))
        page.StatusPage.set_description(_("Next, create your account. Bluefin keeps installing in the background."))
        self.win.NavigationView.push(page)
        self._handed_over = False
        self._hand_over_from = GLib.get_monotonic_time() + HAND_OVER_AFTER_SECONDS * 1000000
        GLib.timeout_add_seconds(HAND_OVER_AFTER_SECONDS, self._maybe_hand_over)

    def resume(self, state, step, fraction, message):
        # New account's session: show where the install is.
        self._status_content = StatusDisplay(self)
        self.installer.on_progress = self._on_progress
        page = self._status_content
        page.RecoveryKeyDisplay.set_visible(False)
        page.Progress.set_fraction(fraction)
        page.StepLabel.set_label(step)
        self.win.NavigationView.push(page)
        if state == 'finished':
            self._on_finished()
        elif state == 'failed':
            self._on_error(message)

    def _load_disks(self):
        """Fill the disk list from the daemon. Without it there is no list."""
        disk_list = self._disk_selector.DiskList
        disk_list.remove_all()
        self._install_button.set_can_target(False)
        try:
            disks = self.installer.disks()
        except dbus.DBusException as error:
            self.alert(_("The Disks Could Not Be Read"), error_text(error))
            return
        for disk in disks:
            disk_list.append(DiskRow(*disk))

    def _disk_selected(self, from_list, selected):
        self._install_button.set_can_target(selected is not None)

    def on_activate(self, app):
        self.install_action.activate(None)

    def on_activate_installer(self, app, parameter):
        if os.getuid() >= 60000:
            # initial setup and greeter sessions never show the installer
            self.quit()
            return
        try:
            self.installer = Installer(self._on_finished, self._on_error, self._on_stopped)
            state, step, fraction, key, mok, message = self.installer.status()
        except dbus.DBusException:
            # No install daemon (an installed system), or this user may not
            # use it.
            self.quit()
            return

        self.win = InstallerWindow()
        self.win.set_application(self)
        if state not in ('idle', 'preparing'):
            self.resume(state, step, fraction, message)
            self.win.present()
            return
        self._disk_selector = DiskSelector()
        self._disk_selector.DiskList.connect("row-selected", self._disk_selected)
        self._install_button = InstallButton(self, self._disk_selector)
        sb_enabled, key_enrolled = self.installer.secure_boot_state()
        row = self._disk_selector.SecureBootRow
        if key_enrolled:
            row.set_active(True)
            row.set_sensitive(False)
            row.set_subtitle(_("Already set up. Nothing more to do."))
        else:
            row.set_subtitle(_("Needed by some anti-cheat games. You confirm Bluefin's key on the next restart with the password: dakota"))
        def on_sb_toggled(*args):
            self.installer.secure_boot = row.get_active()
        row.connect("notify::active", on_sb_toggled)
        self.installer.secure_boot = row.get_active()
        encryption = self._disk_selector.EncryptionRow
        blocker = self.installer.encryption_blocker()
        if blocker:
            encryption.set_active(False)
            encryption.set_sensitive(False)
            encryption.set_subtitle(blocker)
        def on_encryption_toggled(*args):
            self.installer.encrypt = encryption.get_active()
        encryption.connect("notify::active", on_encryption_toggled)
        self.installer.encrypt = encryption.get_active()
        def on_try():
            # "Install Bluefin" in the app grid opens the installer again.
            self.quit()
        def on_install():
            self._load_disks()
            self.win.Header.pack_end(self._install_button)
            self.win.NavigationView.push(self._disk_selector)
        install_or_live = InstallOrLive(on_try, on_install)
        logo = '/usr/share/pixmaps/img-logo-icon.svg'
        if os.path.exists(logo):
            from gi.repository import Gdk
            install_or_live.StatusPage.set_paintable(Gdk.Texture.new_from_filename(logo))
        self.win.NavigationView.push(install_or_live)
        self.win.present()

if __name__ == '__main__':
    dbus.mainloop.glib.DBusGMainLoop(set_as_default=True)
    mainloop = GLib.MainLoop()
    app = InstallerApp(mainloop, application_id="org.gnome.Installer")
    app.run(sys.argv)
