"""Read-only installer regression tests; all mutations use temporary homes.

Run with: python3 -m unittest discover -s tests -v
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

INSTALLER = Path(__file__).resolve().parents[1] / "install.sh"
SOURCE = INSTALLER.read_text()
# Extract definitions only. Never source or execute the installer itself.
FUNCTIONS = SOURCE[
    SOURCE.index("require_pipewire_dropin_state() {"):
    SOURCE.index("require_root_directory_or_absent() {")
]
NAME = "10-wireplumber.conf"
LEGACY = "/usr/share/examples/wireplumber/10-wireplumber.conf"


class AudioSetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        self.repo = self.home / "dotfiles-stow"
        self.conf = self.home / ".config/pipewire/pipewire.conf.d"
        self.conf.mkdir(parents=True)
        self.target = self.conf / NAME
        self.source = self.repo / "pipewire/.config/pipewire/pipewire.conf.d" / NAME
        self.source.parent.mkdir(parents=True)
        self.source.write_text('context.exec = []\n')
        self.env = dict(os.environ, USER_HOME=str(self.home),
                        DOTFILES_DIR=str(self.repo), PIPEWIRE_DIR=str(self.conf))

    def run_functions(self, command):
        harness = ('set -eu\nrun_as_user() { "$@"; }\n'
                   'user_path_exists() { test -e "$1" || test -L "$1"; }\n')
        return subprocess.run(["sh", "-c", harness + FUNCTIONS + command],
                              env=self.env, capture_output=True, text=True)

    def check(self, function="require_pipewire_dropin_state"):
        return self.run_functions(f"{function} {NAME} {LEGACY}\n")

    def test_absent_is_accepted_without_creation(self):
        self.assertEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertFalse(self.target.is_symlink())

    def test_legacy_link_migrates_and_is_rerunnable(self):
        self.target.symlink_to(LEGACY)
        self.assertEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertEqual(self.target.resolve(), self.source)
        self.assertEqual(self.check("migrate_pipewire_dropin").returncode, 0)

    def test_relative_stow_link_is_accepted(self):
        self.target.symlink_to(os.path.relpath(self.source, self.conf))
        self.assertEqual(self.check().returncode, 0)

    def test_absolute_package_link_is_normalized_for_stow(self):
        self.target.symlink_to(self.source)
        self.assertEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertEqual(str(self.target.readlink()), os.path.relpath(self.source, self.conf))

    def test_failed_link_creation_restores_previous_link(self):
        self.target.symlink_to(LEGACY)
        command = (
            'run_as_user() {\n'
            f'  if [ "$1" = ln ] && [ "$3" != "{LEGACY}" ]; then return 1; fi\n'
            '  "$@"\n}\n'
            f'migrate_pipewire_dropin {NAME} {LEGACY}\n'
        )
        self.assertNotEqual(self.run_functions(command).returncode, 0)
        self.assertEqual(str(self.target.readlink()), LEGACY)

    def test_dangling_stow_link_is_accepted_in_preflight(self):
        self.source.unlink()
        self.target.symlink_to(os.path.relpath(self.source, self.conf))
        self.assertEqual(self.check().returncode, 0)

    def test_custom_file_is_preserved(self):
        self.target.write_text("custom\n")
        self.assertNotEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertEqual(self.target.read_text(), "custom\n")

    def test_unrelated_symlink_is_preserved(self):
        self.target.symlink_to("/unrelated/missing.conf")
        self.assertNotEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertEqual(str(self.target.readlink()), "/unrelated/missing.conf")

    def test_missing_package_does_not_remove_legacy_link(self):
        self.source.unlink()
        self.target.symlink_to(LEGACY)
        self.assertNotEqual(self.check("migrate_pipewire_dropin").returncode, 0)
        self.assertEqual(str(self.target.readlink()), LEGACY)

    @unittest.skipUnless(shutil.which("stow"), "GNU Stow not installed")
    def test_fresh_and_migrated_homes_stow_cleanly(self):
        for legacy in (False, True):
            with self.subTest(legacy=legacy):
                if self.target.is_symlink():
                    self.target.unlink()
                if legacy:
                    self.target.symlink_to(LEGACY)
                    self.assertEqual(self.check("migrate_pipewire_dropin").returncode, 0)
                result = subprocess.run([
                    "stow", "--simulate", f"--dir={self.repo}",
                    f"--target={self.home}", "pipewire"
                ], capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)

    def startup_files(self):
        script = self.home / ".config/sway/scripts/start-audio.sh"
        script.parent.mkdir(parents=True)
        script.write_text("#!/bin/sh\n")
        script.chmod(0o755)
        (self.home / ".bash_profile").write_text("    exec dbus-run-session sway >sway.log 2>&1\n")
        (self.home / ".config/sway/config").write_text(
            'exec "exec flock --nonblock --close $XDG_RUNTIME_DIR/sway-audio.lock '
            '$HOME/.config/sway/scripts/start-audio.sh"\n')
        return script

    def test_separate_startup_is_accepted(self):
        self.startup_files()
        self.assertEqual(self.run_functions("validate_sway_startup").returncode, 0)

    def test_commented_audio_startup_is_rejected(self):
        self.startup_files()
        (self.home / ".config/sway/config").write_text(
            "# exec ~/.config/sway/scripts/start-audio.sh\n")
        self.assertNotEqual(self.run_functions("validate_sway_startup").returncode, 0)

    def test_old_wrapper_startup_is_rejected(self):
        self.startup_files()
        (self.home / ".bash_profile").write_text(
            "exec dbus-run-session ~/.config/sway/scripts/start-session.sh\n")
        self.assertNotEqual(self.run_functions("validate_sway_startup").returncode, 0)

    def test_nonexecutable_helper_is_rejected(self):
        self.startup_files().chmod(0o644)
        self.assertNotEqual(self.run_functions("validate_sway_startup").returncode, 0)


if __name__ == "__main__":
    unittest.main()
