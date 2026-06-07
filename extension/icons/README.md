# Icons (pending)

`manifest.json` references these PNGs — they must exist before the Xcode build
and App Store submission, but are **not yet generated**:

- `icon-48.png`
- `icon-96.png`
- `icon-128.png`
- `icon-256.png`
- `icon-512.png`

Design: plain neutral pin or compass needle, single flat color, no badge, no
animation. Generate with the `sharp` rasterization approach reused from the GPQ
icon pipeline (one master SVG → the sizes above).
