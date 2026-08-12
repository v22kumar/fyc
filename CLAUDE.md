# Working agreements for this repository

## Ship it: PR, then merge to main

**Every change ends merged to `main`.** Open a pull request, wait for the
checks, merge it. Deployment is not a separate decision and not something to
hand back — `.github/workflows` takes it from there:

| Workflow | Fires on a push to `main` touching | Deploys |
| --- | --- | --- |
| `fly-deploy.yml` | `backend/**` | the API |
| `web-deploy.yml` | `web/**` | fycconnect.com |
| `admin-deploy.yml` | `admin/**` | the admin portal |
| `flutter-build.yml` | `mobile/**` | the Android build + release |

Work parked on a branch has not shipped, and the club cannot see it. The club
found this out the slow way: a finance page nobody could reach, then a set of
nav links nobody could see, each because a green branch sat unmerged.

The one thing that does stop a merge is a **red check**. The workflows are the
gate — do not merge past them, and do not merge past a flaky one either. A test
that fails on CI and passes locally is a defect in the test; pull the failing
job's log, fix the cause, and push. Re-running until it goes green teaches
everyone to ignore the only signal that guards `main`.

After merging, confirm the deploy workflow actually succeeded, and say which
you checked — this container cannot reach `fycconnect.com` or
`api.fycconnect.com`, so "the deploy succeeded" and "I loaded the page" are
different claims and should never be reported as the same one.

## Schema changes

There is no migration tool. `create_all` at startup makes brand-new tables for
free; an altered column needs a hand-written line in the reconcile list in
`app/main.py`, and a forgotten one has already taken down every read of
`user_profiles`. Prefer new tables. Compile new models against the Postgres
dialect before merging — the test suite runs on SQLite and will not catch a
type or index-name problem that only Postgres has.

## Money

Integer paise, never a float and never `Numeric`. SQLite has no decimal type,
so the arithmetic that passes in CI is not the arithmetic production performs.
See `docs/design/the-clubs-money.md`.

## Toolchains are pinned

CI pins the Flutter version, not the channel, in every workflow that installs
it — tests, the web build, and the release build alike. `channel: stable` is a
moving target: the golden tests once passed at 18:26 and failed at 23:12 on a
commit that touched no mobile code, because a new stable landed in between and
text antialiasing shifted by a third of a percent.

That matters twice over. A gate that goes red on its own is a gate people learn
to merge past, and an unpinned release build means the APK a member installs was
built on whichever SDK happened to be stable that morning.

Taking a new Flutter is a deliberate change: bump the pin, run
`flutter test --tags golden --update-goldens`, and look at the pictures before
accepting them.
