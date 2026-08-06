# Four languages, no exceptions

**The rule: every user-facing string exists in every registered language.**

Not a habit, not a checklist — two tests that run in CI on every push. A rule
nobody can forget is worth more than a rule everybody agrees with.

## Why it has to be enforced

`trId()` falls back to English when a key is missing. That is the right runtime
behaviour — a member should never see a blank label or a crash — and it is a
terrible way to find out. Nothing throws. Nothing logs. The screen simply comes
out half in English.

Which is exactly what shipped. The Tamil blood-donation sheet, on the screen
that matters most to a club in Nagercoil, said:

> அவர்களுக்கு அறிவிப்பு செல்லும், ஏற்கலாம்.
> **Units** — 1 +
> **Hospital (optional)**

And the chess screen had a Tamil headline over `Games Played`, `Best Rating`,
`Win Streak`. Nothing was broken. Those words had simply never been offered for
translation.

## The two tests

**`registry_parity_test.dart`** — every key English has, every other language
has. It also checks the reverse (a key no language can reach is a typo) and
that `{placeholders}` survive translation, because `{n} donors` rendered as
`donors` silently drops the number.

**`no_hardcoded_strings_test.dart`** — parity cannot see a label that was never
registered. This walks the source for text handed straight to a widget
(`label:`, `title:`, `hintText:`, `tooltip:` …) and fails on anything that
never reached the registry. It is deliberately narrow: a blanket "no string
literals" rule would be noise nobody reads.

Between them: nothing can be added in one language, and nothing can skip the
registry.

## Adding a fifth language

Two lines.

1. Create `lib/core/l10n/registry/xx.dart` with `const Map<String, String> kXx`.
2. Add `'xx': kXx,` to `kStrings` and `'xx'` to `kRegisteredLangs`.

No call sites change. The parity test then covers the new language
automatically and tells you exactly which keys are outstanding — so "add a
language" is a list you can work through rather than a hunt.

The backend has the same rule and the same shape: `app/core/i18n.py`,
`REGISTERED_LANGS`, guarded by `tests/test_i18n.py`.

## What this cost, and what it caught

335 strings translated into Tamil, Hindi and Malayalam: 279 that were
registered but untranslated, and 56 more that were hardcoded into widgets and
had never been registered at all.

Three layout bugs came with them, all the same shape — a container sized for
English:

- The chess stat row overflowed by 32px once `Games Played` became
  `விளையாடிய ஆட்டங்கள்`. Each stat now takes a quarter and labels wrap to two
  lines.
- `DSButton` sized its label rigidly, so `மீண்டும் முயற்சிக்கவும்` hung off the
  end of the retry button and the middle of the words stopped being tappable.
  Labels are `Flexible` now, which fixes every button in the app at once.
- The chess legends table was `const`, so its titles resolved at compile time
  in whichever language came first. It stores ids now and resolves them where
  it draws.

That is the real reason the rule is worth having. Translating a string is not
the hard part; discovering that the box it lives in was measured in English is.
