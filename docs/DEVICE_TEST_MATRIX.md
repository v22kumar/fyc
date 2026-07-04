# Device & Network Test Matrix (Sprint 1)

A manual QA reference for validating FYC Connect on the conditions its real
users actually have: cheap Android phones, patchy village connectivity, low
battery, low storage. Run this matrix before any release that touches a
feature screen, and always before an event-day deploy.

## Devices

| Tier | Example device | RAM | Why it matters |
|---|---|---|---|
| Low-end | Redmi 9A / Samsung Galaxy A03 (or Android emulator, API 26, 2GB RAM) | 2GB | The realistic median device in the target villages |
| Mid-range | Redmi Note series / Samsung M-series | 4GB | Common upgrade tier |
| Reference | Pixel 6a (the app's stated primary target) | 6GB+ | Baseline "everything should feel fast" device |

## Network profiles

Test each critical flow (Home load, Feed load + post, Cricket ball-by-ball
scoring, Event registration) under all four:

| Profile | How to simulate |
|---|---|
| **WiFi / 4G** | Normal — your dev network |
| **3G** | Android Emulator → Extended controls → Cellular → Network type "LTE"/"3G", or Chrome DevTools remote-debug throttling on a physical device via `adb` port-forward |
| **2G / Edge** | Emulator Cellular → "GPRS"/"EDGE"; or `adb shell settings put global captive_portal_mode 0` + a network-limiting proxy (Charles/Proxyman rate-limit rule, e.g. 20kbps down / 10kbps up, 400ms latency) |
| **Offline** | Airplane mode toggled mid-flow (start an action online, go offline before it completes) — this is the scenario the write-outbox (Sprint 3) exists for |

## Battery / power conditions

- **Normal**
- **Battery Saver / Low Power Mode ON** — verify the OS's own data-saver signal is respected once Sprint 3's device-profile lands; for Sprint 1, verify nothing crashes and animations still degrade gracefully.
- **< 15% battery, screen brightness low** — a sanity pass for one-handed, low-visibility use.

## Storage conditions

- **Normal free space**
- **< 200MB free** — verify the app doesn't crash on install/update and image caching doesn't fail silently (full offline caching lands in Sprint 3; for now, confirm no crash).

## What to check every pass

- [ ] Cold start time (from tap to interactive Home)
- [ ] No full-screen spinners — skeletons only (`DSSkeletonList` / existing `ShimmerCardList`)
- [ ] Every empty list shows a `DSEmptyState` / `EmptyState`, never raw "no data"
- [ ] Every failure shows a human message (`DSErrorState`), never a raw status code
- [ ] Tap targets are comfortably reachable one-handed in both portrait orientations
- [ ] Tamil, Hindi, Malayalam, English all render correctly (no tofu boxes, no clipped text)
- [ ] Light and dark mode both readable in direct sunlight simulation (max screen brightness + phone held at an angle)

## How this fits the roadmap

Sprint 1 introduces this matrix and the design-system component gallery
(`/design-system` route) to review against it. **Actual offline behavior,
adaptive image tiers, and the device-profile signal are Sprint 3 work** — this
matrix is used from Sprint 1 onward to observe current behavior and confirm
Sprint 3's changes measurably improve it (e.g. record cold-start time on 2G
now, compare after Sprint 3 ships).
