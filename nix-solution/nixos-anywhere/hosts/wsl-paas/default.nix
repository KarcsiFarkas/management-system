# WSL PaaS Configuration
# For testing PaaS services locally on NixOS WSL
{ config, lib, pkgs, inputs, username, ... }:

{
  imports = [
    # WSL-specific module
    inputs.nixos-wsl.nixosModules.wsl
  ];

  # === System Configuration ===
  system.stateVersion = "24.11";
  networking.hostName = "wsl-paas";

  # WSL IP address (update if it changes)
  # Current IP: 172.26.159.132

  # === WSL Configuration ===
  wsl = {
    enable = true;
    defaultUser = username;
    startMenuLaunchers = true;

    # Note: nativeSystemd is now always enabled (deprecated option removed)

    # WSL integration
    wslConf = {
      network = {
        hostname = "wsl-paas";
        generateResolvConf = true;  # Let WSL manage the file
      };
      interop.appendWindowsPath = false;
    };
  };

  # Use static DNS servers - these will be written to /etc/resolv.conf by WSL
  networking.nameservers = [ "8.8.8.8" "1.1.1.1" ];

  # Disable NixOS's resolvconf to avoid conflicts with WSL
  networking.resolvconf.enable = false;

  # === User Configuration ===
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    shell = lib.mkForce pkgs.zsh;  # Override default bash from common/users.nix
  };

  # WSL-specific: Don't require password for sudo (override common/users.nix)
  security.sudo.wheelNeedsPassword = lib.mkForce false;

  # === Enable PaaS Services ===
  services.paas = {
    # Infrastructure - Using WSL-friendly ports to avoid conflicts
    traefik = {
      enable = true;
      domain = "172.26.159.132.nip.io";  # Wildcard DNS using nip.io

      # WSL-specific ports (avoid system ports 80, 443, 8080)
      ports = {
        http = 8090;      # Instead of 80 (often used by system)
        https = 8443;     # Instead of 443
        dashboard = 9080; # Instead of 8080 (often used by system)
      };
    };

    # Authentication & Management
    # authelia.enable = true;  # Uncomment when module is fixed
    # homer.enable = true; # Replaced by homepage-dashboard
    vaultwarden.enable = true;
    authentik = {
      enable = true;
      port = 9000;
      domain = "auth.172.26.159.132.nip.io";
    };

    # Storage & Collaboration
    # nextcloud.enable = true;  # Uncomment when module is fixed

    # Media Services
    jellyfin.enable = true;

    # Development
    gitea.enable = true;
    
    # Dashboard
    homepage-dashboard.enable = true;
  };

  # === Homepage Dashboard Configuration ===
  services.homepage-dashboard = {
    services = [
      {
        "PaaS Services" = [
          {
            "Traefik" = {
              icon = "traefik.svg";
              href = "http://traefik.172.26.159.132.nip.io:8090";
              description = "Reverse Proxy Dashboard";
            };
          }
          {
            "Authentik" = {
              icon = "authentik.svg";
              href = "http://auth.172.26.159.132.nip.io:8090";
              description = "Identity Provider";
            };
          }
          {
            "Jellyfin" = {
              icon = "jellyfin.svg";
              href = "http://jellyfin.172.26.159.132.nip.io:8090";
              description = "Media Server";
            };
          }
          {
            "Vaultwarden" = {
              icon = "bitwarden.svg";
              href = "http://vaultwarden.172.26.159.132.nip.io:8090";
              description = "Password Manager";
            };
          }
          {
            "Gitea" = {
              icon = "gitea.svg";
              href = "http://gitea.172.26.159.132.nip.io:8090";
              description = "Git Server";
            };
          }
        ];
      }
    ];
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
    ];
  };

  # === Traefik Configuration for Homepage & Authentik ===
  services.traefik.dynamicConfigOptions = {
    http.routers = {
      homepage = {
        rule = "Host(`dashboard.172.26.159.132.nip.io`)";
        service = "homepage";
        entryPoints = [ "web" "websecure" ];
      };
      authentik = {
        rule = "Host(`auth.172.26.159.132.nip.io`)";
        service = "authentik";
        entryPoints = [ "web" "websecure" ];
        priority = 10; # Ensure it captures auth requests
      };
    };
    
    http.services = {
      homepage.loadBalancer.servers = [
        { url = "http://127.0.0.1:8082"; }
      ];
      authentik.loadBalancer.servers = [
        { url = "http://127.0.0.1:9000"; }
      ];
    };
  };

  # === Docker Support ===
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # === Firewall ===
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22    # SSH
      8090  # Traefik HTTP (WSL-specific)
      8443  # Traefik HTTPS (WSL-specific)
      9080  # Traefik dashboard (WSL-specific)
      # 8088  # Homer
      8082  # Homepage Dashboard
      8096  # Jellyfin HTTP
      8920  # Jellyfin HTTPS
      8222  # Vaultwarden
      3000  # Gitea
      9000  # Authentik
    ];
  };

  # === System Packages ===
  environment.systemPackages = with pkgs; [
    # Essential tools
    helix      # Modern modal editor (default)
    vim        # Fallback editor
    git
    curl
    wget
    htop

    # Terminal multiplexer and shell enhancements
    zellij      # Modern terminal multiplexer (replaces tmux)
    starship    # Cross-shell prompt
    zoxide      # Smarter cd command
    atuin       # Magical shell history
    bat         # Better cat with syntax highlighting
    eza         # Better ls (modern replacement for exa)

    # File manager and dependencies
    (inputs.yazi.packages.${pkgs.system}.default.override {
      _7zz = pkgs._7zz-rar;  # Support for RAR extraction
    })
    # Yazi dependencies for preview and features
    ffmpegthumbnailer  # Video thumbnails
    unar              # Archive preview
    jq                # JSON preview
    poppler-utils     # PDF preview
    fd                # File searching
    ripgrep           # Content searching
    fzf               # Fuzzy finder
    imagemagick       # Image operations

    # Docker tools
    docker-compose

    # Network tools
    dig
    netcat
    tcpdump
  ];

  # === Nix Configuration ===
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" username ];
    };
  };

  # Allow unfree packages (needed for 7zz-rar)
  nixpkgs.config.allowUnfree = true;

  # === Environment Variables ===
  environment.sessionVariables = {
    # Ensure proper PATH for all shells
    EDITOR = "hx";     # Helix editor
    VISUAL = "hx";     # Helix editor
    HELIX_RUNTIME = "${pkgs.helix}/lib/runtime";  # Helix runtime path

    # Zoxide data directory (optional - uses default if not set)
    _ZO_DATA_DIR = "$HOME/.local/share/zoxide";

    # Atuin configuration
    ATUIN_NOBIND = "true";  # We handle keybindings manually for better control
  };

  # === Shell Configuration ===
  programs.zsh = {
    enable = true;

    # Enable completions (critical for proper tool integration)
    enableCompletion = true;

    # Enable autosuggestions for better UX
    autosuggestions.enable = true;

    # Enable syntax highlighting
    syntaxHighlighting.enable = true;

    # History configuration
    histSize = 50000;
    histFile = "$HOME/.zsh_history";

    # Zsh options set before any initialization
    setOptions = [
      "HIST_IGNORE_ALL_DUPS"
      "HIST_FIND_NO_DUPS"
      "HIST_SAVE_NO_DUPS"
      "SHARE_HISTORY"
      "INC_APPEND_HISTORY"
      "EXTENDED_HISTORY"
    ];

    # Shell aliases
    shellAliases = {
      # Helix editor aliases
      hx = "helix";
      vi = "helix";    # Override vi to use helix

      # Zellij aliases (replaces tmux)
      zj = "zellij";
      zja = "zellij attach";
      zjl = "zellij list-sessions";
      zjk = "zellij kill-session";

      # Note: 'y' alias removed - using function instead (defined below)

      # Convenient shortcuts
      ll = "ls -lah";
      la = "ls -A";
      l = "ls -CF";
      cat = "bat";  # Better cat with syntax highlighting

      # Git shortcuts
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph --decorate";
    };

    # Early initialization (runs before interactive setup)
    shellInit = ''
      # Ensure nix profile is in PATH (critical for WSL)
      if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
      fi
    '';

    # Prompt initialization (runs after shellInit, before interactiveShellInit)
    promptInit = ''
      # Initialize Starship prompt
      eval "$(${pkgs.starship}/bin/starship init zsh)"
    '';

    # Interactive shell initialization (runs last, for interactive shells only)
    interactiveShellInit = ''
      # Initialize zoxide (smarter cd command)
      eval "$(${pkgs.zoxide}/bin/zoxide init zsh)"

      # Initialize atuin (magical shell history)
      eval "$(${pkgs.atuin}/bin/atuin init zsh --disable-up-arrow)"

      # Yazi shell wrapper for directory changing
      # This MUST be a function (not an alias) to support the cd wrapper
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
          builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      }

      # Zellij auto-start (optional - comment out if you don't want auto-start)
      # if [[ -z "$ZELLIJ" ]]; then
      #   zellij attach --create default
      # fi
    '';
  };

  # === Starship Configuration ===
  programs.starship = {
    enable = true;
    settings = {
      add_newline = true;

      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };

      directory = {
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        symbol = " ";
      };

      git_status = {
        conflicted = "🏳";
        ahead = "⇡\${count}";
        behind = "⇣\${count}";
        diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
        untracked = "🤷";
        stashed = "📦";
        modified = "📝";
        staged = "[++($count)](green)";
        renamed = "👅";
        deleted = "🗑";
      };

      nix_shell = {
        symbol = " ";
        format = "via [$symbol$state]($style) ";
      };

      docker_context = {
        symbol = " ";
      };
    };
  };

  # === Additional Configuration ===
  # Atuin config file (optional - users can customize at ~/.config/atuin/config.toml)
  environment.etc."atuin/config.toml".text = ''
    auto_sync = true
    sync_frequency = "5m"
    sync_address = "https://api.atuin.sh"
    search_mode = "fuzzy"
    filter_mode = "global"
    style = "compact"
    inline_height = 20
    show_preview = true
    exit_mode = "return-query"
    keymap_mode = "vim-normal"
  '';

  # Yazi config directory structure will be created on first run
  # Users can customize at ~/.config/yazi/

  # === Services ===
  services.openssh.enable = true;
}
