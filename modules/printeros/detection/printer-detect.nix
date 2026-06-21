# Printer auto-detection — the runtime registry. At boot it scans
# /dev/serial/by-id/* against every enabled printer's mcuMatch glob, picks the
# active printer, assembles its Klipper config into the writable config dir, and
# rewrites [mcu] serial to the resolved device. Then Klipper starts.
{ config, lib, pkgs, ... }:
let
  printers = lib.filterAttrs (_: p: p.enable) config.printeros.printers;

  # Bundle every printer's base config + macros into the store, addressable by name.
  configsDir = pkgs.runCommand "printeros-printer-configs" { } (
    ''mkdir -p $out'' + lib.concatStrings (lib.mapAttrsToList
      (name: p: ''
        mkdir -p $out/${name}
        cp ${p.baseConfig} $out/${name}/printer.cfg
        ${lib.optionalString (p.macros != null) "cp ${p.macros} $out/${name}/macros.cfg"}
      '')
      printers)
  );

  # name|glob lines for the detector to iterate, in declaration order.
  matchTable = lib.concatStringsSep "\n"
    (lib.mapAttrsToList (name: p: "${name}|${p.mcuMatch}") printers);
in
{
  config = lib.mkIf config.printeros.printerStack.enable {
    environment.etc."printeros/printer-matches".text = matchTable;

    systemd.tmpfiles.rules = [
      "d /var/lib/printeros/klipper 0755 printeros printeros -"
      "d /var/lib/printeros/klipper/gcodes 0755 printeros printeros -"
    ];

    systemd.services.printeros-printer-detect = {
      description = "PrinterOS: detect connected printer and assemble active config";
      wantedBy = [ "multi-user.target" ];
      before = [ "klipper.service" ];
      after = [ "printeros-device-detect.service" "dev-serial-by\\x2did.device" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      path = [ pkgs.coreutils pkgs.findutils pkgs.gnused ];
      script = ''
        set -eu
        active=""; dev=""
        while IFS='|' read -r name glob; do
          [ -n "$name" ] || continue
          for cand in /dev/serial/by-id/$glob; do
            if [ -e "$cand" ]; then active="$name"; dev="$cand"; break; fi
          done
          [ -n "$active" ] && break
        done < /etc/printeros/printer-matches

        if [ -z "$active" ]; then
          logger -t printeros "no known printer detected; Klipper will idle"
          echo "PRINTER=" >> /run/printeros/caps.env
          exit 0
        fi

        logger -t printeros "printer detected: $active on $dev"
        echo "PRINTER=$active" >> /run/printeros/caps.env

        base=${configsDir}/$active
        out=/var/lib/printeros/klipper
        # Seed the base only if not already present (preserve prior calibration).
        if [ ! -e "$out/printer.cfg" ]; then
          sed "s#^serial:.*#serial: $dev#" "$base/printer.cfg" > "$out/printer.cfg"
          [ -e "$base/macros.cfg" ] && cp "$base/macros.cfg" "$out/macros.cfg" || true
          touch "$out/saved.cfg"
          # Ensure SAVE_CONFIG output is honored via a writable include.
          grep -q 'include saved.cfg' "$out/printer.cfg" || \
            printf '\n[include saved.cfg]\n' >> "$out/printer.cfg"
        else
          # Keep calibration; just refresh the live serial path.
          sed -i "s#^serial:.*#serial: $dev#" "$out/printer.cfg"
        fi
        chown -R printeros:printeros "$out"
      '';
    };
  };
}
