# Complaint Box — what it looks like

Rendered through the Flutter SDK at 390×844 with the app's real typeface, by
`mobile/test/features/complaint_box/render_harness_test.dart`.

    flutter test --tags render

The harness is tagged `render` and skipped by a bare `flutter test`. It is a
camera, not an assertion suite — and in a headless container it does not always
shut down cleanly, which would hang CI rather than fail it. A hung build is
worse than a red one.

Photographs, not assertions. The point is to look.

## What looking found

Everything below compiled, passed its tests, and was wrong.

**The ladder screen showed no phone numbers.** A screen whose whole job is
"here is who to ring", with not one digit on it — just a name and an
unlabelled icon.

**"Start here" never rendered.** The condition was `index == 0 && canCall`, and
row zero is the Ward Councillor, who has no number. The single piece of
guidance in the design silently never appeared.

**An office you could write to today was greyed out** and labelled as having no
number. `can_call` and `can_write` were split on the server precisely so this
could not happen, and the widget collapsed them again by dimming on `!canCall`.

**Two amber warnings dominated four rows.** The member came to find somebody to
ring; half the screen was shouting about gaps in our own directory.

**Nothing read as a ladder.** Four identical cards. The architecture is built on
the member always seeing the next step, and there was no visual sequence at all.

**The District Collector's call button was as inviting as the ward engineer's.**
Give those equal weight and people ring the Collector about a bulb.

**The send sheet copied the supervisor without telling the member.** Serious
complaints CC the next rung up. The blind copy to the club is a disclosed
switch because a copy somebody does not know about is something done to them —
and that does not stop being true because it is a CC rather than a BCC.

## Not a bug

The timeline first rendered as a red error screen: `DateFormat` throws without
locale data. `main.dart` initialises it at startup; the harness did not. The
app was fine, the camera was not.
