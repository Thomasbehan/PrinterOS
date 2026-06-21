# DRY base shared by EVERY printer (not device-specific). Enables the printing
# stack and the UI; individual printer profiles only declare their deltas.
{ ... }:
{
  printeros.printerStack.enable = true;
  printeros.ui.enable = true;
}
