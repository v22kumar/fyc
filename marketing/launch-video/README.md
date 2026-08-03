# FYC Connect — Launch Video

Source for the FYC Connect launch/promo video, authored in the Claude Design
motion runtime (`x-dc`). Sixteen scenes walk through the real app: Home,
Today's Summary, Thirukkural, News, Community Feed, Sports Arena, Serve/Help,
Blood Donation, Report an Issue, Jobs, Events, Safety/SOS, Profile, Members,
and a closing card.

Imported from the Claude Design project **"FYC Connect launch video"**
(`d0a2fecf-e558-4e33-a296-2b135599dfb9`).

## Files

| File | Role |
|------|------|
| `FYC Connect Launch.dc.html` | Entry point. Declares the scene list (`OM_SCENES`), playback, fonts, and imports the component. |
| `fyc-launch.jsx` | The whole video — every scene, the phone shell (green chess banner + bottom nav + orange FAB + SOS), captions, and narration sync. |
| `animations-v2.jsx` | The motion engine (Stage/SceneStage, Easing, `interpolate`, `useTimeline`, `useScene`, exportable-video wiring). Do not edit by hand. |
| `support.js` | Generated `x-dc` runtime (parses the `.dc.html`, mounts React, drives the timeline). Do not edit by hand. |
| `assets/` | Logos, imagery, and the narration audio the scenes reference. |

## Rendering / editing

This is a Claude Design `x-dc` piece. Open/edit/export it inside the Claude
Design canvas (the host provides React and the export pipeline). The scene
durations and playback in `FYC Connect Launch.dc.html` are the source of truth;
the host's trim/speed gestures write back into that file.

The `accent` and `showEnglish` props are editable in the design panel
(`accent` defaults to the teal `#14B891`; the palette also offers the app's
orange `#F59E0B`).

## Assets

`assets/logos/fyc_app_icon.png` is included. The remaining assets referenced by
the scenes are the project's own high-resolution uploads that exceed the design
MCP's 256 KiB per-file fetch limit, so they could not be vendored here through
the import. Export them from the Claude Design project into these exact paths
before rendering standalone:

```
assets/imagery/hero_community.png     # Intro / Closing photo strip
assets/imagery/blood_drive.png        # Blood Donation scene hero
assets/imagery/impact_sapling.png     # Closing photo strip
assets/imagery/beach_clean.png        # Closing photo strip
assets/imagery/sports_cricket.png     # Sports Arena scene hero
assets/imagery/events_hall.png        # Events scene hero
assets/audio/narration.mp3            # Voice-over (drives Narration sync)
```

Inside the Claude Design project these already exist and the video renders
end-to-end; the list above is only for a self-contained checkout.
