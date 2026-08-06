# One door, many roads

A club of a hundred people should not be locked out of its own app because a
vendor in San Francisco is having a bad afternoon.

## The bug

`/auth/otp/send` was an if/else:

```python
if settings.TWILIO_VERIFY_SID:
    if not send_verify_otp(phone):
        raise HTTPException(502, "Couldn't send the OTP right now.")   # ← stop
    ...
else:
    otp = _generate_otp()
    deliver_otp(phone, otp, email)        # WhatsApp, then email
```

`otp_sender.py` has a WhatsApp sender and an email sender, written for exactly
this situation. They were reachable **only when Twilio Verify was not configured
at all** — so the moment Verify is configured and failing, which is the moment
they exist for, they are unreachable code.

Twilio Verify fails for ordinary reasons: an outage, an expired credential, a
spent trial balance, an unverified number on a trial account, a carrier
rejecting a route into India. Any of those, and every member of the club sees
*"Couldn't send the OTP right now"* — with three working channels sitting
unused behind an `else`.

## The ladder

Each channel is now tried in turn until one accepts the message:

| | why it is where it is |
|---|---|
| **Twilio Verify (SMS)** | first, because it works on every phone ever made — no app, no data, no account |
| **WhatsApp** | second, and for this audience arguably better than SMS: near-universal in Tamil Nadu, and it survives an SMS route being blocked |
| **Email** | third, for members who gave one |
| **an organizer** | last, and human. The error now says *"ask an organizer to let you in"* rather than *"try again shortly"*, because trying again will not help |

Whichever one carried it is reported back and named in the app: *"Sent on
WhatsApp to +91…"*. Pointing a member at their messages when the code went to
WhatsApp is, from where they are standing, indistinguishable from nothing
having been sent.

When nothing carries it, the verification id is discarded rather than handed
back — it would have pointed at a message that does not exist.

## Why this matters more than the credential

The credential can be fixed in the Fly dashboard in a minute. The architecture
could not: **a single vendor was a single point of failure for every member's
access to the entire app**, on a day when a hundred people are standing in a
hall waiting to play chess.

That is the part worth having fixed before the tournament, and it is the part
that stays fixed.

## Old phones, new phones

Nothing in this path needs a modern device:

- **Phone number + a typed code** — works on any handset with a SIM.
- **Google sign-in** needs Play Services, which is missing on some cheap
  handsets and all recent Huawei devices. It is an accelerator, never the only
  door, and the app does not degrade when it is absent.
- **SMS auto-read** (`AutofillHints.oneTimeCode`) is a convenience that
  gracefully does nothing on phones that do not support it — the field is still
  a plain text field.
- **Passkeys**, when they come, need Android 9+ and a screen lock. They will be
  an addition to this ladder and never a replacement, for exactly this reason.

The floor is a ten-year-old phone with a SIM and no Play Services. Everything
above the floor is an accelerator.


## The build could ship an APK that cannot sign in

```yaml
--dart-define=GOOGLE_SERVER_CLIENT_ID=${GOOGLE_SERVER_CLIENT_ID:-}
```

`String.fromEnvironment` falls back to its default only when the define is
**absent**. An *empty* one wins. So a GitHub secret that was unset, renamed or
lost expanded to `--dart-define=GOOGLE_SERVER_CLIENT_ID=` and shipped a release
with no client id at all — at which point Google Sign-In returns a null idToken
and fails with nothing in the logs that names the cause.

From the outside that is indistinguishable from "Google sign-in is down", and
no amount of checking credentials in the Firebase console would have found it,
because the credentials were fine.

Fixed on both sides, because either alone would have been enough:

* the workflow omits the flag entirely when the secret is empty, and prints a
  build warning
* `ApiConstants` treats an empty override as no override

## Being able to ask the app what is configured

`GET /api/health/auth`

```json
{
  "can_deliver_a_code": false,
  "channels": {
    "sms_twilio_verify": false,
    "whatsapp_twilio": false,
    "email_smtp": false,
    "otp_bypass": false
  },
  "google_sign_in": { "configured_client_ids": 0,
                      "accepts_first_party_defaults": true },
  "environment": "development",
  "allowed_origins": ["https://fycconnect.com", "..."]
}
```

Configuration, never values — knowing `TWILIO_AUTH_TOKEN` is set is the
diagnosis; knowing what it is would be a leak, and a test asserts nothing
secret-shaped ever appears in the response.

Unauthenticated, deliberately, for the same reason a health check is: the
moment you most need to ask this question is the moment nobody can sign in.

`can_deliver_a_code: false` is the whole answer when the answer is bad. After a
deploy, that one line tells you in a second what previously took an afternoon
and dashboard access to three services.


## Web works, Android does not — what that rules out

Both doors work from a browser and neither works from the APK. That single fact
eliminates most of the search space:

* the backend is fine — the browser proves Twilio, the endpoints and the
  database all work
* `api.fycconnect.com` is fine — `web/fly.toml` bakes in the *same* host the
  APK does
* CORS is fine — Android does not do CORS

So both failures are inside the APK, and one commit changed both things at once:

```
05cf1cc  chore: Update package name for Google Play release and update action API URL
         --dart-define=API_BASE_URL=https://fyc-backend.fly.dev
      →  --dart-define=API_BASE_URL=https://api.fycconnect.com
```

### Google Sign-In on Android

Two candidates, both matching "worked, then a Play release, then stopped":

1. **The empty define** — fixed above. A missing `GOOGLE_SERVER_CLIENT_ID`
   secret shipped an APK with no client id, and Google returns a null idToken.
2. **Play App Signing.** `google-services.json` registers `com.fycconnect.app`
   with certificate hash `aed4c410…`. When an app is distributed through Play,
   Google **re-signs it with its own key** — so the SHA-1 that reaches Google at
   runtime is the *app signing key*, not the upload key that is usually what
   ends up in Firebase. This is the single most common cause of "Google
   Sign-In works from a sideloaded APK and fails from the Play Store".

   Fix: Play Console → Setup → App signing → copy the **App signing key
   certificate** SHA-1 → add it to the `fyc-connect-25ab0` Android app in
   Firebase → re-download `google-services.json`. Both fingerprints should be
   registered, upload and app-signing, so sideloaded and Play builds both work.

### OTP on Android

Nothing in the server explains it, so the remaining candidates are all
client-side, and one of them is about old handsets specifically:

* **an APK built before `05cf1cc`**, still pointing at `fyc-backend.fly.dev`.
  If that hostname stopped answering when the domain moved, everything in that
  build fails — and login is where you notice first, because it used to be the
  gate.
* **TLS on old Android.** Fly issues Let's Encrypt certificates. Android 7 and
  below shipped a trust store that does not chain them cleanly, while Chrome
  carries its own — so a browser succeeds on the very phone where the app
  cannot open the socket. Exactly the "older phones" case.

## Making the app say which

Guessing between those took an afternoon. Every sign-in failure is now reported
through the existing crash reporter, tagged with the step it died on:

```
auth/phone   sign-in failed at phone: <the actual error>
auth/code    sign-in failed at code:  …
```

A TLS failure, a 502 out of Twilio and a null idToken produce three different
messages and land in `/api/v1/diagnostics/errors` beside the crashes. One
member trying once is now enough to know which of the causes above it is.
