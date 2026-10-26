"""Offline shell/launcher tests. No real credentials or user startup files are used."""

import base64
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
SHELLS = ("bash", "zsh")


def executable(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content)
    path.chmod(0o755)


class ShellTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dotfiles-shell-test-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name) / "home"
        shutil.copytree(REPO / "shell", self.home)
        (self.home / ".hushlogin").touch()
        self.env = {
            "HOME": str(self.home), "ZDOTDIR": str(self.home),
            "PATH": "/usr/bin:/bin", "TERM": "dumb", "LC_ALL": "C.UTF-8",
        }
        executable(self.home / ".local/bin/starship", "#!/bin/sh\nprintf ':\\n'\n")
        self.fnm = self.home / ".local/share/fnm/fnm"
        executable(self.fnm, '''#!/bin/sh
printf '%s\n' "$*" >> "$HOME/fnm-calls"
printf 'export PATH="$HOME/project-node/bin:$PATH"\n'
''')
        self.cargo = self.home / ".cargo/env"
        self.cargo.parent.mkdir()
        self.cargo.write_text('printf "cargo\\n" >> "$HOME/cargo-calls"\n')
        shutil.copy2(REPO / "pi/.local/bin/pi", self.home / ".local/bin/pi")
        executable(self.home / "project-node/bin/pi", "#!/bin/sh\nexit 99\n")

    def shell(self, shell, code, *, login=False, args=(), input=None):
        command = [shutil.which(shell)]
        if login:
            command.append("-l")
        command += ["-ic", code, "dotfiles-test", *args]
        return subprocess.run(command, cwd=self.home, env=self.env, input=input,
                              text=True, capture_output=True, timeout=20)

    def check(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_login_and_nonlogin_share_helpers_and_initialize_once(self):
        for shell in SHELLS:
            for login in (False, True):
                with self.subTest(shell=shell, login=login):
                    for name in ("fnm-calls", "cargo-calls"):
                        (self.home / name).unlink(missing_ok=True)
                    result = self.shell(shell, '''
command -v secret_env >/dev/null || exit 1
command -v jwt-decode >/dev/null || exit 1
command -v up >/dev/null || exit 1
alias ll >/dev/null || exit 1
[ "$EDITOR" = nvim ] || exit 1
[ "$(command -v pi)" = "$HOME/.local/bin/pi" ] || exit 1
printf '%s' "$PATH"
''', login=login)
                    self.check(result)
                    self.assertEqual(result.stdout.split(":").count(str(self.home / ".local/bin")), 1)
                    self.assertEqual((self.home / "cargo-calls").read_text().splitlines(), ["cargo"])
                    self.assertEqual((self.home / "fnm-calls").read_text().splitlines(), [
                        f"env --shell {shell} --use-on-cd --version-file-strategy recursive --resolve-engines=false"
                    ])

    def test_optional_tools_can_be_absent(self):
        self.fnm.unlink()
        self.cargo.unlink()
        (self.home / ".local/bin/starship").unlink()
        for shell in SHELLS:
            with self.subTest(shell=shell):
                result = self.shell(shell, "command -v secret_env >/dev/null && printf READY")
                self.check(result)
                self.assertEqual(result.stdout, "READY")
                self.assertNotIn("not found", result.stderr)
                self.assertNotIn("no such file", result.stderr.lower())

    def test_profile_is_posix_and_path_prepend_is_idempotent(self):
        result = subprocess.run(["sh", "-c", '''
. "$HOME/.profile"
PATH="/usr/bin:$HOME/.local/bin:/bin:$HOME/.local/bin"
path_prepend "$HOME/.local/bin"
path_prepend "$HOME/.local/bin"
[ "$PATH" = "$HOME/.local/bin:/usr/bin:/bin" ]
'''], env=self.env, capture_output=True, text=True)
        self.check(result)

    def test_noninteractive_zsh_loads_cargo_but_not_interactive_helpers(self):
        result = subprocess.run([shutil.which("zsh"), "-c", '''
[ ! -e "$HOME/fnm-calls" ] && ! command -v secret_env >/dev/null
'''], env=self.env, capture_output=True, text=True)
        self.check(result)
        self.assertEqual((self.home / "cargo-calls").read_text().splitlines(), ["cargo"])

    def test_up_validates_arguments_and_handles_spaces_and_zero(self):
        directory = self.home / "project with spaces/deep/deeper"
        directory.mkdir(parents=True)
        for shell in SHELLS:
            with self.subTest(shell=shell):
                result = self.shell(shell, '''
cd -- "$1" || exit 1
up 0 || exit 1
[ "$PWD" = "$1" ] || exit 1
for invalid in -1 nope '' '1+1'; do
  if up "$invalid"; then exit 1; fi
  [ "$PWD" = "$1" ] || exit 1
done
if up 1 2; then exit 1; fi
[ "$PWD" = "$1" ] || exit 1
up 02 || exit 1
[ "$PWD" = "$HOME/project with spaces" ] || exit 1
up || exit 1
[ "$PWD" = "$HOME" ] || exit 1
up 08 || exit 1
[ "$PWD" = / ]
''', args=(str(directory),))
                self.check(result)

    def test_jwt_base64url_and_invalid_tokens(self):
        def encode(value):
            raw = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode()
            return base64.urlsafe_b64encode(raw).decode().rstrip("=")

        header, claims = {"alg": "HS256", "typ": "JWT"}, {"x": "🦀"}
        self.assertIn("-", encode(claims))
        token = f"{encode(header)}.{encode(claims)}.not-a-real-signature"
        for shell in SHELLS:
            with self.subTest(shell=shell):
                result = self.shell(shell, 'jwt-decode "$1"', args=(token,))
                self.check(result)
                self.assertEqual(json.loads(result.stdout), [header, claims])
                result = self.shell(shell, '''
for token in '' a.b a.b.c.d a.e30.sig e30.bad!.sig bnVsbA.e30.sig; do
  if jwt-decode "$token"; then exit 1; fi
done
if jwt-decode; then exit 1; fi
''')
                self.check(result)

    def test_secret_helper_accepts_literal_input_and_preserves_value_on_eof(self):
        value = 'literal $(printf not-executed) "quoted" \\backslash'
        for shell in SHELLS:
            with self.subTest(shell=shell):
                result = self.shell(shell, '''
set -x
if [ -n "${ZSH_VERSION-}" ]; then
  # Zsh restores xtrace on function return: refuse input until the caller disables it.
  if secret_env DOTFILES_TEST_SECRET; then exit 1; fi
  set +x
  [ "${DOTFILES_TEST_SECRET-unset}" = unset ] || exit 1
fi
secret_env DOTFILES_TEST_SECRET || exit 1
[ "$DOTFILES_TEST_SECRET" = "$1" ] || exit 1
case $- in *x*) exit 1 ;; esac
''', args=(value,), input=value + "\n")
                self.check(result)
                self.assertNotIn(value, result.stdout + result.stderr)
                result = self.shell(shell, '''
export DOTFILES_TEST_SECRET=before
if secret_env DOTFILES_TEST_SECRET; then exit 1; fi
[ "$DOTFILES_TEST_SECRET" = before ] || exit 1
if secret_env 'NOT-VALID'; then exit 1; fi
''', input="")
                self.check(result)
                result = self.shell(shell, '''
export DOTFILES_TEST_SECRET=before
secret_env DOTFILES_TEST_SECRET && [ "$DOTFILES_TEST_SECRET" = '' ]
''', input="\n")
                self.check(result)

    def test_pi_launcher_uses_own_node_without_changing_path_or_arguments(self):
        runtime = self.home / "runtime with spaces"
        executable(runtime / "bin/node", '''#!/bin/sh
printf '%s\n' "$@"
printf 'PATH=%s\nCWD=%s\n' "$PATH" "$PWD"
exit 42
''')
        (runtime / "bin/pi").write_text("// test CLI placeholder\n")
        env = dict(self.env, PI_NODE_HOME=str(runtime))
        result = subprocess.run([REPO / "pi/.local/bin/pi", "argument with spaces", "--version"],
                                cwd=self.home, env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 42)
        self.assertEqual(result.stdout.splitlines(), [
            str(runtime / "bin/pi"), "argument with spaces", "--version",
            "PATH=/usr/bin:/bin", f"CWD={self.home}",
        ])

        env.pop("PI_NODE_HOME")
        result = subprocess.run([REPO / "pi/.local/bin/pi", "--version"],
                                env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 127)
        self.assertIn("PI_NODE_HOME", result.stderr)
        self.assertIn("aliases/default", result.stderr)

        fnm_dir = self.home / "custom fnm"
        node_home = fnm_dir / "aliases/default"
        node_home.parent.mkdir(parents=True)
        node_home.symlink_to(runtime, target_is_directory=True)
        result = subprocess.run([REPO / "pi/.local/bin/pi", "--version"],
                                env=dict(env, FNM_DIR=str(fnm_dir)), capture_output=True, text=True)
        self.assertEqual(result.returncode, 42)
        self.assertEqual(result.stdout.splitlines()[0], str(node_home / "bin/pi"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
