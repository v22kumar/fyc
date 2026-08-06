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
