{ config, lib, pkgs, ... }:
let
  cfg = config.services.homer;
in
{
  options.services.homer = {
    enable = lib.mkEnableOption "Homer dashboard (placeholder module)";
  };

  # Placeholder: build-safe default; does nothing unless enabled.
  config = lib.mkIf cfg.enable {
    warnings = [
      "services.homer: placeholder module is enabled. No runtime is configured yet."
    ];
    # Put a real implementation here (e.g., nginx serving ${pkgs.homer} assets or a node service).
  };
}
