# Work — what it looks like

Rendered at 390×844 with the app's real typeface by
`mobile/test/features/work/render_harness.dart`.

    flutter test test/features/work/render_harness.dart

Named without the `_test` suffix so `flutter test` never collects it. It is a
camera, not an assertion suite.

## What looking found

**Two of my string keys already belonged to other features.** `member_since`
was in the registry as "Member Since" and `be_the_first` as something shorter
than I had written, so the cards were rendering somebody else's wording — and
would have changed silently the day that feature was reworded. Namespaced to
`work_*`, the way the category keys already were.

**The trust line wrapped onto two rows** and took as much vertical space as the
description. On a card meant to be scanned in about a second, that signal has
to be readable at a glance rather than read. It is now an icon and one
ellipsised line.

**The tick was a "✓" character**, which is not in Plus Jakarta Sans, so it
rendered as an empty box. A Material icon now.

**A shop's opening hours were dropped entirely** — the one thing that
distinguishes a business from a person here, and what decides whether somebody
rings now or in the morning. Placed after the area, because people ask *where*
before *when*.

**Results were ordered newest-first**, so a listing created five minutes ago
outranked somebody with nine confirmed jobs. The first thing a searcher saw was
the least proven option on the screen — the exact opposite of what the trust
line exists to say. Now grouped: anybody with confirmed work above anybody
without, newest first inside each group. Grouping rather than ranking, because
sorting purely by jobs means nobody new is seen, so nobody new is hired, so
nobody new accumulates jobs, and the index never bootstraps.

**The create screen used `BuildContext` after an awaited haptic.** The analyzer
had said so twice and I had not read it. The widget can be gone by then, and a
disposed-context lookup would crash on the one screen a member only ever uses
once.

## Two harness artifacts, not bugs

Worth writing down so the next person does not chase them.

**Icons render as empty boxes.** The test environment has no Material icon
font. The app is fine.

**Bold text painted nothing, so the category chips looked blank.** Loading
weight 700 through a *second* `FontLoader` for a family does not merge with the
first: the text lays out at the correct width and paints nothing, which in a
screenshot reads as an empty button. Two rounds of this review went into
chasing a chip that was rendering its label perfectly well. Fixed by putting
every weight into one loader — and `work_labels_test.dart` now asserts the
labels resolve, so a real version of that failure cannot hide behind a fake one.
