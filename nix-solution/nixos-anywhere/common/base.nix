# Base system configuration
# Common settings applied to all NixOS-anywhere deployments
{ config, pkgs, lib, ... }:

{
  # === System Versioning ===
  # Update this when changing NixOS versions
  system.stateVersion = "24.11";

  # === Time and Locale ===
  time.timeZone = lib.mkDefault "UTC";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_TIME = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
    };
  };

  # === Console Configuration ===
  console = {
    font = "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  # === Nix Configuration ===
  nix = {
    # Use latest Nix (flakes are now built-in)
    package = pkgs.nix;

    # Enable experimental features
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      # Automatic garbage collection
      auto-optimise-store = true;

      # Build settings for better performance
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Trusted users for remote builds
      trusted-users = [ "root" "@wheel" ];

      # Substituters and binary caches
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    # Automatic garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Optimize store after garbage collection
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # === Boot Configuration ===
  boot = {
    # Clean /tmp on boot
    tmp.cleanOnBoot = true;

    # Kernel parameters
    kernelParams = [
      # Enable kernel logs to console
      "console=tty1"
    ];

    # Latest stable kernel by default
    kernelPackages = lib.mkDefault pkgs.linuxPackages_latest;

    # Bootloader configuration (will be overridden by host-specific configs)
    loader = {
      timeout = lib.mkDefault 5;

      # GRUB configuration
      grub = {
        enable = lib.mkDefault true;
        efiSupport = lib.mkDefault true;
        device = lib.mkDefault "nodev";
      };

      # EFI configuration
      efi.canTouchEfiVariables = lib.mkDefault true;
    };
  };

  # === Essential System Packages ===
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    nano

    # Network tools
    wget
    curl
    rsync
    nmap
    tcpdump
    iperf3

    # System tools
    git
    htop
    tree
    file
    lsof
    psmisc
    pciutils
    usbutils

    # Compression
    zip
    unzip
    gzip
    bzip2
    xz

    # Debugging
    strace
    ltrace
    gdb

    # Monitoring
    iotop
    iftop
    nethogs

    # Security
    openssl
    age
    gnupg
  ];

  # === Shell Configuration ===
  programs.bash = {
    completion.enable = true;
    shellAliases = {
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";

      # NixOS specific
      nixos-rebuild-switch = "sudo nixos-rebuild switch --flake /etc/nixos";
      nixos-rebuild-boot = "sudo nixos-rebuild boot --flake /etc/nixos";
      nixos-generations = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
      nixos-cleanup = "sudo nix-collect-garbage -d";

      # Docker shortcuts (if Docker is enabled)
      dps = "docker ps";
      dpsa = "docker ps -a";
      dlog = "docker logs -f";
    };
  };

  # === Documentation ===
  documentation = {
    enable = true;
    man.enable = true;
    info.enable = true;
    doc.enable = true;
  };

  # === System Services ===
  services = {
    # Automatic system updates (disabled by default for production)
    # Enable per-host if needed
    # system.autoUpgrade = {
    #   enable = false;
    #   allowReboot = false;
    #   flake = "/etc/nixos";
    # };
  };

  # === Logging ===
  services.journald = {
    extraConfig = ''
      SystemMaxUse=1G
      SystemMaxFileSize=100M
      MaxRetentionSec=30d
    '';
  };

  # === Systemd Configuration ===
  systemd = {
    # Make systemd services more resilient
    services = {
      # Extend timeout for service starts
      systemd-udev-settle.serviceConfig.TimeoutSec = "10min";
    };

    # tmpfiles rules
    tmpfiles.rules = [
      # Ensure /tmp has correct permissions
      "d /tmp 1777 root root 10d"

      # Create common directories
      "d /var/log/nixos 0755 root root -"
    ];
  };

  # === Hardware Configuration ===
  hardware = {
    # Enable redistributable firmware only (to avoid requiring allowUnfree)
    # For full hardware support, enable enableAllFirmware and set nixpkgs.config.allowUnfree
    enableRedistributableFirmware = lib.mkDefault true;

    # Enable CPU microcode updates
    cpu.intel.updateMicrocode = lib.mkDefault true;
    cpu.amd.updateMicrocode = lib.mkDefault true;
  };
}
