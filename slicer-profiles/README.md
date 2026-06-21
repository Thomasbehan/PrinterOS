# Slicer setup — FLSUN Q5 on PrinterOS

PrinterOS exposes the printer through Moonraker, so any Klipper-aware slicer
(OrcaSlicer recommended) works. Key settings to get the Bambu-like macros firing:

## Machine

| Setting | Value |
|---|---|
| G-code flavor | **Klipper** |
| Bed shape | **Circular, 200 mm** diameter |
| Max print height | **~200 mm** (set after `DELTA_CALIBRATE`) |
| Nozzle diameter | 0.4 mm |
| Origin | center (delta) |

## Start G-code

```
START_PRINT BED=[bed_temperature_initial_layer_single] HOTEND=[nozzle_temperature_initial_layer]
```

## End G-code

```
END_PRINT
```

## Why this maps cleanly

`START_PRINT` / `END_PRINT` (and `PAUSE`, `RESUME`, `M600`, `LOAD_FILAMENT`,
`UNLOAD_FILAMENT`) are defined in `printers/flsun-q5/macros.cfg`, so the slicer only
passes temperatures — the printer owns the sequence. `[exclude_object]` lets you cancel
a single failed part mid-print, and `[gcode_arcs]` keeps G2/G3 output smooth.

Upload sliced `.gcode` straight from the slicer (Moonraker upload) or via the PrinterOS
web UI. Filament spools tracked in **Spoolman** appear in the UI automatically.
