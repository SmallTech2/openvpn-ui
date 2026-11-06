"""Tests du helper avec commandes systeme simulees, sans acces a un serveur."""
import os
import pathlib
import subprocess
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
BASH = "C:/Program Files/Git/bin/bash.exe" if os.name == "nt" else "/bin/bash"
HELPER = ROOT / "Radio/scripts/secure-ssh.sh"

MOCKS = r'''
getent(){
  [[ "$*" == "passwd $TEST_USER" ]] || return 1
  printf '%s:x:1000:1000::/home/%s:/bin/bash\n' "$TEST_USER" "$TEST_USER"
}
ssh-keygen(){
  [[ "$*" == "-lf /home/$TEST_USER/.ssh/authorized_keys" ]] || return 1
  printf '256 SHA256:fixture test (ED25519)\n'
}
journalctl(){
  [[ "$TEST_CASE" != journal-error ]] || return 1
  if [[ "$TEST_CASE" == wrong-key ]]; then
    echo "Accepted publickey for $TEST_USER from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:other"
  elif [[ "$TEST_CASE" == wrong-user ]]; then
    echo 'Accepted publickey for other from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:fixture'
  else
    echo "Accepted publickey for $TEST_USER from 192.0.2.10 port 50000 ssh2: ED25519 SHA256:fixture"
  fi
}
cp(){ if [[ "$1" == -p ]]; then shift; fi; command cp "$@"; }
test_sshd(){
  printf 'sshd %s\n' "$*" >> "$TEST_TRACE"
  if [[ "$1" == -t ]]; then
    if [[ "$TEST_CASE" == syntax-error && ! -f "$TEST_FAILED" ]]; then touch "$TEST_FAILED"; return 1; fi
    return 0
  fi
  [[ "$TEST_CASE" != effective-error ]] || return 1
  if [[ "$*" != '-T' ]]; then
    [[ "$*" == "-T -C user=$TEST_USER,addr=192.0.2.10,host=192.0.2.10,laddr=192.0.2.20,lport=2222" ]] || return 1
  fi
  case "$TEST_CASE" in
    bad-pubkey) echo 'pubkeyauthentication no' ;;
    *) echo 'pubkeyauthentication yes' ;;
  esac
  if [[ "$TEST_CASE" == bad-methods ]]; then echo 'authenticationmethods any'; else echo 'authenticationmethods publickey'; fi
  if [[ "$TEST_CASE" == bad-password ]]; then echo 'passwordauthentication yes'; else echo 'passwordauthentication no'; fi
  if [[ "$TEST_CASE" == bad-keyboard ]]; then echo 'kbdinteractiveauthentication yes'; else echo 'kbdinteractiveauthentication no'; fi
}
systemctl(){
  [[ "$*" == 'reload ssh' ]] || return 1
  printf 'reload ssh\n' >> "$TEST_TRACE"
  if [[ "$TEST_CASE" == reload-error && ! -f "$TEST_FAILED" ]]; then touch "$TEST_FAILED"; return 1; fi
}
'''


class SSHHardeningTest(unittest.TestCase):
    def run_case(self, case, user="alice"):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            config, trace = root / "sshd.conf", root / "trace"
            original = "PubkeyAuthentication yes\n"
            config.write_text(original, encoding="utf-8", newline="\n")
            trace.write_text("")
            # Seule la copie de test remplace la garde root et les chemins systeme.
            helper = HELPER.read_text(encoding="utf-8")
            helper = helper.replace("[[ $EUID -eq 0 ]] || { echo 'Executer avec sudo.' >&2; exit 1; }", ":")
            helper = helper.replace("CONFIG=/etc/ssh/sshd_config.d/00-radio.conf", 'CONFIG="$TEST_CONFIG"')
            helper = helper.replace("/usr/sbin/sshd", "test_sshd")
            env = dict(os.environ, SUDO_USER=user, TEST_USER=user, TEST_CASE=case,
                       SSH_CONNECTION="192.0.2.10 50000 192.0.2.20 2222",
                       TEST_CONFIG=config.as_posix(), TEST_TRACE=trace.as_posix(),
                       TEST_FAILED=(root / "failed").as_posix())
            result = subprocess.run([BASH], input=MOCKS + helper, encoding="utf-8", capture_output=True, env=env)
            return result, config.read_text(), trace.read_text(), original

    def test_success_for_configurable_accounts(self):
        for user in ("technicien", "alice", "ops-admin_2", "_admin", "a" * 32):
            with self.subTest(user=user):
                result, config, trace, _ = self.run_case("success", user)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("PasswordAuthentication no\n", config)
                self.assertIn("KbdInteractiveAuthentication no\n", config)
                self.assertIn("AuthenticationMethods publickey\n", config)
                self.assertIn("user=" + user + ",addr=", trace)
                self.assertEqual(trace.count("reload ssh"), 1)

    def test_no_change_without_key_proof(self):
        for case in ("wrong-key", "wrong-user", "journal-error"):
            with self.subTest(case=case):
                result, config, trace, original = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(config, original)
                self.assertEqual(trace, "")

    def test_restore_on_validation_or_reload_failure(self):
        for case in ("syntax-error", "effective-error", "bad-pubkey", "bad-methods",
                     "bad-password", "bad-keyboard", "reload-error"):
            with self.subTest(case=case):
                result, config, trace, original = self.run_case(case)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(config, original)
                self.assertIn("reload ssh", trace)


if __name__ == "__main__":
    unittest.main()
