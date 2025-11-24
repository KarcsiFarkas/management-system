# User management configuration
# Provides utilities and defaults for user account management
{ config, pkgs, lib, username, ... }:

{
  # === User Account Configuration ===
  users.users.${username} = {
    isNormalUser = true;
    description = "${username} - System Administrator";

    # Default groups (override per-host as needed)
    extraGroups = [
      "wheel"      # sudo access
      "networkmanager"
      "docker"     # Docker access (if Docker is enabled)
      "systemd-journal" # Read system logs
    ];

    # Create home directory
    createHome = true;
    home = "/home/${username}";

    # Default shell
    shell = pkgs.bash;

    # SSH keys will be added per-host configuration
    # openssh.authorizedKeys.keys = [ ... ];
  };

  # === Root User Configuration ===
  users.users.root = {
    # SSH keys for root (added per-host)
    # openssh.authorizedKeys.keys = [ ... ];

    # Disable root password login
    hashedPassword = lib.mkDefault "!"; # Locked account
  };

  # === Mutable Users ===
  # Allow changing user passwords at runtime
  users.mutableUsers = lib.mkDefault true;

  # === Default User Shell Configuration ===
  programs.bash = {
    shellInit = ''
      # Colorful prompt
      if [ "$TERM" != "dumb" ]; then
        PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
      fi

      # Useful aliases
      alias ll='ls -lah'
      alias la='ls -A'
      alias l='ls -CF'
      alias grep='grep --color=auto'

      # NixOS specific
      alias nixos-switch='sudo nixos-rebuild switch --flake /etc/nixos'
      alias nixos-boot='sudo nixos-rebuild boot --flake /etc/nixos'
      alias nixos-test='sudo nixos-rebuild test --flake /etc/nixos'
      alias nixos-clean='sudo nix-collect-garbage -d'
      alias nixos-list-gens='sudo nix-env --list-generations --profile /nix/var/nix/profiles/system'

      # Docker shortcuts
      alias dps='docker ps'
      alias dpsa='docker ps -a'
      alias dlog='docker logs -f'
      alias dexec='docker exec -it'
      alias dstop='docker stop $(docker ps -q)'
    '';
  };

  # === Zsh Support (Optional) ===
  programs.zsh = {
    enable = lib.mkDefault false;
    # If enabled, configure oh-my-zsh
    # ohMyZsh = {
    #   enable = true;
    #   theme = "robbyrussell";
    #   plugins = [ "git" "docker" "systemd" ];
    # };
  };

  # === Fish Shell Support (Optional) ===
  programs.fish.enable = lib.mkDefault false;

  # === Starship Prompt (Modern, cross-shell) ===
  programs.starship = {
    enable = lib.mkDefault false;
    # settings = {
    #   add_newline = true;
    #   character = {
    #     success_symbol = "[➜](bold green)";
    #     error_symbol = "[➜](bold red)";
    #   };
    # };
  };

  # === User Packages ===
  # Packages available to all users
  environment.systemPackages = with pkgs; [
    # Editors
    vim
    nano
    micro  # Modern alternative to nano

    # Shell utilities
    bat    # Better 'cat'
    eza    # Better 'ls' (successor to exa)
    fd     # Better 'find'
    ripgrep # Better 'grep'
    fzf    # Fuzzy finder
    tmux   # Terminal multiplexer

    # Development tools
    git
    tig    # Text-mode interface for git

    # System monitoring
    htop
    bottom  # Better 'top'
    dust # Better 'du' (formerly du-dust)
    procs   # Better 'ps'

    # Network tools
    curl
    wget
    rsync
  ];

  # === Sudo Configuration for Wheel Group ===
  security.sudo = {
    enable = true;
    wheelNeedsPassword = lib.mkDefault true;
  };

  # === User Groups ===
  users.groups = {
    # Docker group (if Docker is enabled)
    docker = {
      members = [ username ];
    };

    # Additional application-specific groups
    # These will be used by service modules
    traefik = {};
    vaultwarden = {};
    authelia = {};
    nextcloud = {};
    gitlab = {};
  };

  # === Home Directory Skeleton ===
  # Files to copy to new user home directories
  system.activationScripts.createUserDirs = lib.stringAfter [ "users" ] ''
    # Create common directories for ${username}
    for dir in Documents Downloads Projects .config .ssh; do
      mkdir -p /home/${username}/$dir
      chown ${username}:users /home/${username}/$dir
    done

    # Set proper permissions for .ssh
    chmod 700 /home/${username}/.ssh
  '';

  # === User Environment Variables ===
  environment.variables = {
    # Use mkForce since NixOS sets EDITOR=nano by default
    EDITOR = lib.mkForce "vim";
    VISUAL = lib.mkDefault "vim";
    PAGER = lib.mkDefault "less";
  };

  # === Login Message (MOTD) ===
  users.motd = lib.mkDefault ''
    ====================================================
      Welcome to ${config.networking.hostName}
      NixOS ${config.system.nixos.release}
    ====================================================

    System Information:
      - Hostname: ${config.networking.hostName}
      - Kernel: $(uname -r)
      - Uptime: $(uptime -p)

    Quick Commands:
      - nixos-switch     : Apply configuration changes
      - nixos-list-gens  : List system generations
      - nixos-clean      : Clean old generations
      - htop             : System monitor

    ====================================================
  '';

  # === Password Quality Requirements ===
  # FIXME: PAM configuration needs update for NixOS 24.11+
  # Temporarily commented out
  # security.pam.services.passwd.rules.password = {
  #   ...
  # };
}
