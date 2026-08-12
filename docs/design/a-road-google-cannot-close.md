# A road Google cannot close

`code 10` is `DEVELOPER_ERROR`. It means Google does not recognise the pair
**(package name, signing certificate)** that the app presented.

We spent days inside that sentence. Every static check passed:

| Check | Result |
| --- | --- |
| package has no `applicationIdSuffix` | ✅ exactly `com.fycconnect.app` |
| published APK's v2 signing block | ✅ `bbda573d…` |
| that pair in `google-services.json` | ✅ registered |
| web client id belongs to the same project | ✅ `986299606001-…` |
| plugin API correct for `google_sign_in 6.3.0` | ✅ |

And sign-in kept failing.

## The thing all of those checks share

They describe **the APK CI builds**. They say nothing about the APK on the
phone, and those are not always the same artifact.

Play App Signing re-signs every uploaded bundle with a key Google generates and
holds. So the club has at least two shipping certificates:

* the **upload key** — CI's release keystore, `bbda573d…`, what a sideloaded
  APK presents
* the **app signing key** — Google's own, what *every Play install* presents

They are different fingerprints, and they are registered independently. Either
one can be missing from Firebase while the other is fine, which produces the
exact symptom we had: a check that passes, and a member who cannot sign in.

It gets worse for us specifically, because the website's download button now
serves the **Play-signed** universal APK — the deliberate choice made so that a
member who installs from the website can still update from Play. Which means
almost nobody is holding the artifact all those checks describe.

**The console fix, when a fingerprint really is missing:** Play Console →
Test and release → Setup → App integrity → *App signing key certificate* →
copy the SHA-1 → add it to `com.fycconnect.app` in the Firebase console →
re-download `google-services.json`. Both fingerprints should be registered,
upload and app-signing, so sideloaded and Play builds both work.

## What the phone actually said

It reported this, in the failure, on the build the club is running:

```
Google sign-in isn't available on this build (code 10)
This build: com.fycconnect.app
23:E2:1A:60:16:1A:7B:B7:D5:B2:0B:64:C9:67:7B:A5:97:22:A7:41
```

That fingerprint is **neither of the two registered against
`com.fycconnect.app`** — not the CI release key `BB:DA:57:3D…`, and not
`AE:D4:C4:10…`. It is a third certificate, and it is registered nowhere.

Which is the answer, and had been all along. A third certificate signing a
build the club distributes is Play App Signing: Google re-signed the uploaded
bundle with a key it generated and holds, and that key was never added to the
Firebase project. Every check that passed was a check on the artifact CI
builds; nobody is running that artifact.

**The fix takes two minutes and no release.** Add
`23:E2:1A:60:16:1A:7B:B7:D5:B2:0B:64:C9:67:7B:A5:97:22:A7:41` as an SHA-1
fingerprint on `com.fycconnect.app` in the Firebase console. Google performs
the (package, certificate) lookup on its own servers, so registering it fixes
every copy already on a phone — no rebuild, no Play submission, no waiting for
anybody to update. Propagation is minutes.

Worth confirming while there: Play Console → Test and release → Setup → App
integrity → *App signing key certificate*. Its SHA-1 should read
`23:E2:1A:60…`. If it does, this document's guess and the phone's answer are
the same fact arrived at from two directions.

## Why we did not stop there

Because that is a fix for *this* occurrence, and the shape of the problem
guarantees more of them. The signing certificate is a single point of failure
for signing in at all, it lives in a console rather than in the repository, and
nothing in the app can reach it. A key rotation, a new distribution channel, a
second app listing — each one re-opens the same hole, and the symptom is always
a five-word error that names none of it.

So the app now has a second road, and it does not have a certificate anywhere
in it.

## Ordinary web OAuth, in the phone's browser

When the native plugin fails with `code 10` — or accepts the account and
returns a null `idToken`, which is the same fault wearing a different hat — the
app does not tell the member to give up and use their phone number. It opens
Google in the browser.

The browser authenticates against the **web client id**. That is the same
credential the club's website already uses successfully, and Google does not
ask a browser what certificate it was signed with, because a browser was not
signed.

```
POST /auth/google/browser/start    → { session_id, authorization_url }
        app opens authorization_url in the system browser
GET  /auth/google/browser/callback ← Google returns the member here
GET  /auth/google/browser/result   → { status: pending | ready | failed }
```

### Why polling, and not a deep link

The obvious way to get the answer back is a custom URL scheme —
`fycconnect://auth` — registered in the manifest. We are not doing that,
because a custom scheme is *one more per-build thing that can be wrong*, which
is precisely what this whole road exists to escape. A manifest typo would
reproduce the failure we are fixing, in a new place, with a new error message.

Instead the app holds a secret handle. It starts the flow, opens the browser,
and asks the server whether the browser has finished. Google talks only to the
backend; the finished session waits in `pending_browser_logins` until the app
collects it.

### What guards the handle

The handle is the only credential in front of a finished session, so:

* it is 32 bytes from a CSPRNG, generated server-side, and returned only to the
  app that started the flow, over TLS
* it **is** the OAuth `state` — a callback carrying a state we never issued has
  nowhere to land, which is what stops a stranger's callback from completing
  somebody else's sign-in
* it is **single use**. The first successful poll deletes the row
* it lives ten minutes

### What does not change

The rules about who may sign in are shared, not reimplemented. Both roads end
in `session_for_google_identity`, so a blocked member is blocked on both, and a
brand-new Google account is routed to registration — to collect the mandatory
phone number and date of birth — rather than quietly becoming a half-empty
account. That was the point of extracting it: two roads in, one set of rules.

## Setting it up

The fallback stays dormant until it can actually complete — an unconfigured
button that fails is worse than no button, especially handed to somebody who
has just been refused once.

1. **Google Cloud Console** → APIs & Services → Credentials → the **Web
   application** OAuth client → Authorised redirect URIs → add exactly:

   ```
   https://api.fycconnect.com/api/v1/auth/google/browser/callback
   ```

   Character for character. A mismatch here is invisible until a member tries
   to sign in, at which point Google answers `redirect_uri_mismatch` — which
   the app now shows verbatim, rather than translating into something vaguer.

2. **Fly secrets**:

   ```
   fly secrets set GOOGLE_WEB_CLIENT_ID=<the web client id> \
                   GOOGLE_CLIENT_SECRET=<its secret>
   ```

3. Confirm from anywhere:

   ```
   GET /api/health/auth  →  google_sign_in.browser_fallback
   { "available": true, "missing": [], "redirect_uri": "https://…/callback" }
   ```

   `missing` names the settings that are absent, so the answer to "why isn't it
   on" is in the response rather than in somebody's memory.

## What this is not

It is not a replacement for the native plugin. When Google recognises the
build, the native flow is faster and does not leave the app — that stays the
first thing tried. This is what happens instead of a dead end.

And it is not the thing sixty players will use on Saturday. **Phone sign-in
is.** Google is a convenience; the phone number is the door.
