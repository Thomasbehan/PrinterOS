# PrinterOS UI

The management interface — **one app, two targets**: the browser and the on-device
touchscreen kiosk (same build). Talks to Moonraker via JSON-RPC over WebSocket + REST.

## Design language (locked — see CLAUDE.md §6)

Calm minimal / Scandinavian. Light + dark from one semantic token set. The **delta
circle** is the signature motif (round build plate, three towers at 120°), not a
rectangular/linear print view. Monospace for live numerics; one quiet cool accent;
amber reserved strictly for thermal data.

Design concept (clickable, light/dark):
https://claude.ai/code/artifact/8ba1472b-a65a-42cb-b3af-eb6c1b8e1a9e

## Stack

SvelteKit (static adapter) → built to a Nix package consumed by
`modules/printeros/ui/serve.nix` (Caddy). Tiny and fast on a Pi.

## Status

Scaffold. Next: port the design-concept dashboard into SvelteKit components, wire the
Moonraker client, then build the file/tune/console screens.
