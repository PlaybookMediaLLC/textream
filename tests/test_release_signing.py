"""Exercise the real release shell scripts with isolated Apple-tool stand-ins."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = Path(__file__).resolve().parents[1]
IDENTITY = "Developer ID Application: Test (T44K9669GA)"
APPLE_ID_AUTH = {"APPLE_ID": "test@example.invalid", "APPLE_APP_PASSWORD": "fake-password", "APPLE_TEAM_ID": "T44K9669GA"}
API_AUTH = {"APPLE_NOTARY_KEY_PATH": "/fixture/AuthKey.p8", "APPLE_NOTARY_KEY_ID": "key-id", "APPLE_NOTARY_ISSUER_ID": "issuer-id"}

MOCK = r'''
import json, os, pathlib, shutil, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["EVENT_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\n")
if os.environ.get("FAIL_COMMAND") and os.environ["FAIL_COMMAND"] in " ".join([name, *args]):
    sys.exit(9)
if name == "xcodebuild":
    app = pathlib.Path(args[args.index("-archivePath") + 1]) / "Products/Applications/Dante.app"
    for binary in ("MacOS/Dante", "Frameworks/Test.framework/Versions/A/Test", "Frameworks/libtest.dylib"):
        target = app / "Contents" / binary
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("arm64" if "ARCHS=arm64" in args else "x86_64")
elif name == "file":
    print("Mach-O")
elif name == "lipo":
    if args[0] == "-create":
        pathlib.Path(args[-1]).write_text("arm64 x86_64")
    else:
        print(pathlib.Path(args[-1]).read_text())
elif name == "ditto":
    if "-c" in args:
        pathlib.Path(args[-1]).touch()
    else:
        shutil.copytree(args[-2], args[-1])
elif name == "hdiutil":
    source = pathlib.Path(args[args.index("-srcfolder") + 1])
    if os.environ.get("REQUIRE_NOTARIZATION") == "1":
        assert (source / "Dante.app/Contents/.stapled").exists(), "DMG contains an unstapled app"
    pathlib.Path(args[-2]).touch()
elif name == "xcrun":
    if args[:2] == ["notarytool", "submit"]:
        status = "Invalid" if os.environ.get("REJECT_SUFFIX") and args[2].endswith(os.environ["REJECT_SUFFIX"]) else "Accepted"
        print(json.dumps({"status": status}))
    elif args[:2] == ["stapler", "staple"] and args[-1].endswith(".app"):
        (pathlib.Path(args[-1]) / "Contents/.stapled").touch()
elif name == "security" and args[0] == "find-identity":
    if not os.environ.get("NO_IDENTITY"):
        print('  1) ABCDEF "Developer ID Application: Test (T44K9669GA)"')
'''


class ReleaseSigningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dante release ")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        shim = self.bin / "mock"
        shim.write_text(f"#!{sys.executable}\n" + MOCK)
        shim.chmod(0o755)
        for name in ("xcodebuild", "file", "lipo", "codesign", "xattr", "ditto", "hdiutil", "xcrun", "spctl", "security"):
            (self.bin / name).symlink_to(shim)
        self.script = self.root / "build.sh"
        shutil.copyfile(ROOT / "Textream/build.sh", self.script)
        self.log = self.root / "events.jsonl"
        self.env = {"PATH": f"{self.bin}:{os.environ['PATH']}", "EVENT_LOG": str(self.log), "RUNNER_TEMP": str(self.root), "GITHUB_ENV": str(self.root / "github-env")}

    def run_build(self, **env):
        result = subprocess.run(["/bin/bash", str(self.script)], env=self.env | env, text=True, capture_output=True)
        events = [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []
        return result, events

    def test_required_credentials_fail_before_clean_or_build(self):
        sentinel = self.root / "build/release/keep"
        sentinel.parent.mkdir(parents=True)
        sentinel.touch()
        for env in ({}, {"SIGNING_IDENTITY": IDENTITY}, APPLE_ID_AUTH, {"SIGNING_IDENTITY": "-", **APPLE_ID_AUTH}, {"SIGNING_IDENTITY": IDENTITY, "APPLE_NOTARY_KEY_PATH": "only-one-field"}):
            with self.subTest(env=env):
                result, events = self.run_build(REQUIRE_NOTARIZATION="1", **env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Release requires", result.stderr)
                self.assertEqual(events, [])
                self.assertTrue(sentinel.exists())

    def test_local_adhoc_build_still_works(self):
        result, events = self.run_build()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(e[0] == "xcrun" for e in events))
        self.assertTrue(any(e[:4] == ["codesign", "--force", "--sign", "-"] and e[-1].endswith(".framework") for e in events))

    def test_both_auth_modes_staple_before_packaging(self):
        for auth in (APPLE_ID_AUTH, API_AUTH):
            with self.subTest(auth=list(auth)):
                self.log.unlink(missing_ok=True)
                result, events = self.run_build(REQUIRE_NOTARIZATION="1", SIGNING_IDENTITY=IDENTITY, **auth)
                self.assertEqual(result.returncode, 0, result.stderr)
                submissions = [e for e in events if e[:3] == ["xcrun", "notarytool", "submit"]]
                self.assertEqual(len(submissions), 2)
                self.assertTrue(submissions[0][3].endswith(".zip"))
                self.assertTrue(submissions[1][3].endswith(".dmg"))
                for submission in submissions:
                    self.assertIn("--apple-id" if auth is APPLE_ID_AUTH else "--key", submission)
                app_staple = next(i for i, e in enumerate(events) if e[:3] == ["xcrun", "stapler", "staple"] and e[-1].endswith(".app"))
                packaging = next(i for i, e in enumerate(events) if e[0] == "hdiutil")
                self.assertLess(app_staple, packaging)
                self.assertFalse(any(e[0] == "xattr" for e in events[app_staple:]))
                self.assertEqual(len([e for e in events if e[:3] == ["xcrun", "stapler", "validate"]]), 2)
                self.assertEqual(len([e for e in events if e[0] == "spctl"]), 2)
                signed = [e[-1] for e in events if e[:2] == ["codesign", "--force"]]
                self.assertLess(next(i for i, p in enumerate(signed) if p.endswith(".framework")), next(i for i, p in enumerate(signed) if p.endswith(".app")))

    def test_rejected_notarization_stops_release(self):
        for suffix in (".zip", ".dmg"):
            with self.subTest(suffix=suffix):
                result, _ = self.run_build(REQUIRE_NOTARIZATION="1", SIGNING_IDENTITY=IDENTITY, REJECT_SUFFIX=suffix, **APPLE_ID_AUTH)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Notarization was not accepted", result.stderr)
                self.assertNotIn("Done!", result.stdout)

    def test_tool_failures_stop_release(self):
        for command in ("codesign --force", "codesign --verify", "xcrun notarytool submit", "xcrun stapler staple", "xcrun stapler validate", "spctl --assess --type execute", "spctl --assess --type open"):
            with self.subTest(command=command):
                result, _ = self.run_build(REQUIRE_NOTARIZATION="1", SIGNING_IDENTITY=IDENTITY, FAIL_COMMAND=command, **APPLE_ID_AUTH)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("Done!", result.stdout)

    def run_setup(self, **env):
        workflow = (ROOT / ".github/workflows/release.yml").read_text()
        step = workflow.split("      - name: Configure required Developer ID signing & Apple notarization\n", 1)[1].split("\n      - name:", 1)[0]
        script = textwrap.dedent(step.split("        run: |\n", 1)[1])
        secrets = {name: "" for name in ("MACOS_CERT_P12_BASE64", "MACOS_CERT_PASSWORD", "MACOS_SIGNING_IDENTITY", "APPLE_NOTARY_KEY_BASE64", "APPLE_NOTARY_KEY_ID", "APPLE_NOTARY_ISSUER_ID", "APPLE_ID", "APPLE_APP_PASSWORD", "APPLE_TEAM_ID")}
        return subprocess.run(["/bin/bash", "-euo", "pipefail", "-c", script], env=self.env | secrets | env, capture_output=True, text=True)

    def test_workflow_rejects_missing_and_partial_secrets(self):
        for env in ({}, {"MACOS_CERT_P12_BASE64": "Zml4dHVyZQ=="}, {"MACOS_CERT_P12_BASE64": "Zml4dHVyZQ==", "MACOS_CERT_PASSWORD": "fake"}, {"MACOS_CERT_P12_BASE64": "Zml4dHVyZQ==", "MACOS_CERT_PASSWORD": "fake", "APPLE_NOTARY_KEY_BASE64": "Zml4dHVyZQ==", "APPLE_NOTARY_KEY_ID": "key"}):
            with self.subTest(env=list(env)):
                result = self.run_setup(**env)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("::error::Release requires", result.stdout)
                self.assertFalse(self.log.exists())

    def test_workflow_exports_each_auth_mode(self):
        for auth in ({"APPLE_ID": "test@example.invalid", "APPLE_APP_PASSWORD": "fake"}, {"APPLE_NOTARY_KEY_BASE64": "Zml4dHVyZQ==", "APPLE_NOTARY_KEY_ID": "key", "APPLE_NOTARY_ISSUER_ID": "issuer"}):
            with self.subTest(auth=list(auth)):
                result = self.run_setup(MACOS_CERT_P12_BASE64="Zml4dHVyZQ==", MACOS_CERT_PASSWORD="fake", **auth)
                self.assertEqual(result.returncode, 0, result.stderr)
                exports = (self.root / "github-env").read_text()
                self.assertIn(f"SIGNING_IDENTITY={IDENTITY}", exports)
                self.assertIn("APPLE_TEAM_ID=T44K9669GA" if "APPLE_ID" in auth else "APPLE_NOTARY_KEY_PATH=", exports)
                self.assertEqual((self.root / "developer-id.p12").stat().st_mode & 0o777, 0o600)

    def test_workflow_rejects_certificate_without_private_identity(self):
        result = self.run_setup(MACOS_CERT_P12_BASE64="Zml4dHVyZQ==", MACOS_CERT_PASSWORD="fake", NO_IDENTITY="1", **APPLE_ID_AUTH)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("no Developer ID Application identity", result.stdout)


if __name__ == "__main__":
    unittest.main()
