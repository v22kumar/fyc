#!/usr/bin/env python3
"""Refuse to ship an APK whose signing key Google will not recognise.

Google Sign-In matches on the **pair** (package name, signing certificate).
Either one alone is meaningless. When the pair is not registered in the
Firebase project, `signIn()` returns a null idToken or throws DEVELOPER_ERROR,
and the app can say nothing more useful than "Google login isn't configured
yet" — which sounds like a missing setting and is actually a mismatched
fingerprint.

That is exactly what shipped. The release key was registered against
`com.example.fyc_connect` — the default package Flutter creates a project with,
long since renamed — while the app ships as `com.fycconnect.app` with a
different certificate on file. Both halves looked present. Neither pair matched.

Nothing in the build noticed, because nothing was looking. This looks, and
fails the build with the fingerprint to add and the place to add it.

    python3 tool/check_google_signin.py <sha1-of-signing-key>

The SHA-1 comes from the keystore the build is about to sign with; the release
workflow already prints it.
"""
import json
import pathlib
import sys

CONFIG = pathlib.Path(__file__).resolve().parents[1] / "android/app/google-services.json"
GRADLE = pathlib.Path(__file__).resolve().parents[1] / "android/app/build.gradle.kts"


def shipping_package() -> str:
    """The applicationId the APK will actually carry."""
    for line in GRADLE.read_text().splitlines():
        if "applicationId" in line and "=" in line:
            return line.split("=", 1)[1].strip().strip('"')
    raise SystemExit("could not read applicationId from build.gradle.kts")


def normalise(fingerprint: str) -> str:
    return fingerprint.replace(":", "").replace(" ", "").strip().lower()


def main() -> int:
    if len(sys.argv) < 2 or not sys.argv[1].strip():
        print("[google-signin] no signing fingerprint given — skipping check")
        return 0

    signing = normalise(sys.argv[1])
    package = shipping_package()
    config = json.loads(CONFIG.read_text())

    registered: dict[str, list[str]] = {}
    for client in config.get("client", []):
        name = client["client_info"]["android_client_info"]["package_name"]
        for oauth in client.get("oauth_client", []):
            digest = oauth.get("android_info", {}).get("certificate_hash")
            if digest:
                registered.setdefault(name, []).append(normalise(digest))

    if signing in registered.get(package, []):
        print(f"[google-signin] ✓ {package} is registered with this key")
        return 0

    print("::error::Google Sign-In will fail in this build.")
    print(f"  the app ships as : {package}")
    print(f"  signed with SHA-1: {signing}")
    print(f"  registered for that package: "
          f"{registered.get(package) or 'nothing'}")
    elsewhere = [p for p, digests in registered.items()
                 if signing in digests and p != package]
    if elsewhere:
        print(f"  this key IS registered, but under: {', '.join(elsewhere)}")
        print("  -> the fingerprint is on the wrong app in the Firebase project")
    print("")
    print("  Fix: Firebase Console -> Project settings -> Your apps ->")
    print(f"       {package} -> Add fingerprint -> {signing}")
    print("       then download google-services.json and commit it.")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
