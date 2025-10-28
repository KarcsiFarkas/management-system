{ config, lib, pkgs, ... }:
let
  cfg = config.services.immich;
in
{
  options.services.immich = {
    enable = lib.mkEnableOption "Immich photo service (placeholder module)";
  };

  # Placeholder: build-safe default; does nothing unless enabled.
  config = lib.mkIf cfg.enable {
    warnings = [
      "services.immich: placeholder module is enabled. No runtime is configured yet."
    ];
    # Put a real implementation here (e.g., composeContainers/podman with immich-server/db/redis).
  };
}
