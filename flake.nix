{
  description = "gnu — NixOS + ChromaShell (Caelestia/Hyprland)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    prismlauncher-cracked.url = "github:Diegiwg/PrismLauncher-Cracked";
    chromashell.url = "github:SecLBL/ChromaShell-Flake";
    chromashell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, home-manager, chromashell, ... }@inputs: {
    nixosConfigurations.gnu = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        ./hardware-laptop.nix
        chromashell.nixosModules.default

        ({ pkgs, ... }: let
          customEdid = pkgs.runCommandNoCC "custom-100hz-edid" {} ''
            mkdir -p $out/lib/firmware/edid
            cp ${./100hz.bin} $out/lib/firmware/edid/100hz.bin
          '';
        in {
          hardware.firmware = [ customEdid ];
        })

        ({ pkgs, config, ... }: {
          time.timeZone = "Europe/Moscow";
          programs.chromashell-system.enable = true;
          nixpkgs.config.allowUnfree = true;

          nix.settings.experimental-features = [ "nix-command" "flakes" ];
          zramSwap = {
            enable = true;
            priority = 100;
            memoryPercent = 150;
            swapDevices = 1;
            algorithm = "zstd";
          };
          boot = {
            kernelPackages = pkgs.linuxPackages_latest;
            kernelModules = [ "v4l2loopback" "usbhid" ];
            extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
            kernel.sysctl = { "vm.max_map_count" = 2147483642; };
            extraModprobeConfig = "options usbhid mousepoll=1";

            kernelParams = [
              "usbhid.mousepoll=1"
              "drm.edid_firmware=eDP-1:edid/100hz.bin"
              "nowatchdog"
            ];

            loader.systemd-boot.enable = true;
            loader.efi.canTouchEfiVariables = true;

            binfmt.registrations.appimage = {
              wrapInterpreterInShell = false;
              interpreter = "${pkgs.appimage-run}/bin/appimage-run";
              recognitionType = "magic";
              offset = 0;
              mask = ''\xff\xff\xff\xff\x00\x00\x00\x00\xff\xff\xff'';
              magicOrExtension = ''\x7fELF....AI\x02'';
            };
            plymouth.enable = false;
          };

          networking.hostName = "gnu";
          networking.networkmanager.enable = true;
          services.flatpak.enable = true;

          programs.steam = {
            enable = true;
            remotePlay.openFirewall = true;
            dedicatedServer.openFirewall = true;
          };
          programs.gamemode.enable = true;

          environment.systemPackages = with pkgs; [
            git
            nwg-look
            gtk3
            curl
            neovim
            pciutils
            materialgram
            heroic
            inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
          ];

          users.users.gnu = {
            isNormalUser = true;
            extraGroups = [ "wheel" "networkmanager" "video" ];
          };
          system.stateVersion = "24.11";
        })

        # Home Manager
        home-manager.nixosModules.home-manager
        ({ pkgs, ... }: {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.gnu = { pkgs, ... }: {
            imports = [ chromashell.homeManagerModules.default ];

            home.packages = [
            
            ];
            home.pointerCursor = {
              name = "Bibata-Material-Cloud";
              size = 28;
              package = pkgs.runCommand "bibata-material-cloud" {} ''
                mkdir -p $out/share/icons
                ln -s /home/gnu/.local/share/icons/bibata-material-v1.0.0/Bibata-Material-Cloud $out/share/icons/Bibata-Material-Cloud
              '';
              gtk.enable = true;
              x11.enable = true;
            };

            programs.chromashell = {
              enable = true;
              browser = { app = "brave"; manage = true; };
              editor = { app = "vscode"; manage = true; };
              comms = { app = "vencord"; manage = true; };
              music = { app = "spicetify"; manage = true; };
            };
            home.stateVersion = "24.11";
          };
        })
      ];
    };
  };
}
