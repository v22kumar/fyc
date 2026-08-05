# Design review — August 2026

Every member-facing screen, opened in the real app at phone size and photographed.

The app was built screen by screen without anyone seeing it running. This is the
first look at all of it together, and the recurring finding is exactly what that
process would predict: each area is decent on its own terms, and no two areas
agree on what those terms are.

## Reproducing this

```sh
# 1. a backend with content, so screens are populated rather than empty
cd backend
export DATABASE_URL="sqlite:////tmp/review.db" SKIP_BULK_SEED=1 SCHEDULER_ENABLED=false
python -m uvicorn app.main:app --port 8151 &

# 2. walk every route and save what renders
cd ../mobile
xvfb-run -a --server-args="-screen 0 1400x1100x24" \
  flutter run -d linux -t lib/dev_screenshot_harness.dart \
  --dart-define=API_BASE_URL=http://127.0.0.1:8151 \
  --dart-define=TOKEN="<a member token>" \
  --dart-define=DEV_AUTH_BYPASS=true \
  --dart-define=OUT=/tmp/shots
```

`lib/dev_screenshot_harness.dart` holds the route list. Add a screen there and it
joins the next review.

## Two caveats on these images

- `DEV_AUTH_BYPASS` makes every route reachable, so a couple of screens show
  signed-out states a real member would not hit.
- Home's "update available" sheet is an artefact of the local backend's version
  number. The harness dismisses any modal before capturing.

## The findings

1. **Two languages inside a single sentence** — Tamil headings over English
   bodies; the bottom navigation is entirely English.
2. **Floating buttons sit on top of the content** — the `+` covers the
   announcement it floats over.
3. **Chess is a different app** — dark, English-only, its own palette, while
   everything else is light and Tamil.
4. **Horizontal rows are clipped** — Tamil is longer than English, and layouts
   sized against English run off the edge.
5. **Empty states occupy the best space** — Home's top half says "check back
   shortly" twice.
6. **Five headers, four greens, no shared shell.**
7. **Two doors to the same room** — a gear icon and a Settings row on one screen.
8. **Numbers shown before there are any** — `0.0K Active Citizens`.
9. **One stock photograph for every event.**
10. **Error text that argues with itself** — three stacked, conflicting messages.

The fix is not a redesign of each screen. It is a small number of shared
decisions applied everywhere: one language rule, one header component, one green,
one primary action per screen, and a decision about whether chess is part of the
house style or a deliberate second world.
