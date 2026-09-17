{
  description = "gnu — NixOS + ChromaShell (Caelestia/Hyprland)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    chaotic.url = "https://flakehub.com/f/chaotic-cx/nyx/*.tar.gz";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    wayvibes.url = "github:sahaj-b/wayvibes";
    wayvibes.inputs.nixpkgs.follows = "nixpkgs";

    prismlauncher-cracked.url = "github:Diegiwg/PrismLauncher-Cracked";

    aagl.url = "github:ezKEa/aagl-gtk-on-nix";
    aagl.inputs.nixpkgs.follows = "nixpkgs";

    chromashell.url = "github:SecLBL/ChromaShell-Flake";
    chromashell.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, home-manager, chromashell, chaotic, ... }@inputs:
    {
      nixosConfigurations.gnu = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };

        modules = [
          ./hardware-configuration.nix
          ./hardware-laptop.nix
          chromashell.nixosModules.default
          chaotic.nixosModules.nyx-cache
          chaotic.nixosModules.nyx-overlay
          chaotic.nixosModules.nyx-registry
          inputs.aagl.nixosModules.default

          (
            { pkgs, ... }:
            let
              customEdid = pkgs.runCommandNoCC "custom-100hz-edid" { } ''
                mkdir -p $out/lib/firmware/edid
                cp ${./100hz.bin} $out/lib/firmware/edid/100hz.bin
              '';
            in
            {
              hardware.firmware = [ customEdid ];
            }
          )

          (
            { pkgs, config, ... }:
            {
              time.timeZone = "Europe/Moscow";
              programs.chromashell-system.enable = true;
              nixpkgs.config.allowUnfree = true;

              nix.settings = inputs.aagl.nixConfig // {
                experimental-features = [ "nix-command" "flakes" ];
                auto-optimise-store = true;
                substituters = (inputs.aagl.nixConfig.substituters or []) ++ [ "https://nyx-cache.chaotic.cx/" ];
                trusted-public-keys = (inputs.aagl.nixConfig.trusted-public-keys or []) ++ [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
              };

              programs.sleepy-launcher.enable = true;

              nix.gc = {
                automatic = true;
                dates = "weekly";
                options = "--delete-older-than 7d";
              };

              zramSwap = {
                enable = true;
                priority = 100;
                memoryPercent = 150;
                swapDevices = 1;
                algorithm = "zstd";
              };

              boot = {
                kernelPackages = pkgs.linuxPackages_cachyos-bore;
                kernelModules = [ "v4l2loopback" "usbhid" "uinput" ];
                extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];

                kernel.sysctl = {
                  "vm.max_map_count" = 2147483642;
                };

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
              services.getty.autologinUser = "gnu";

              environment.loginShellInit = ''
                if uwsm check may-start; then
                  exec uwsm start hyprland-uwsm.desktop
                fi
              '';

              programs.nix-ld.enable = true;
              programs.nix-ld.libraries = with pkgs; [
                stdenv.cc.cc.lib
                zlib
                libGL
              ];

              programs.steam = {
                enable = true;
                remotePlay.openFirewall = false;
                dedicatedServer.openFirewall = true;
              };

              programs.gamemode.enable = true;

              programs.ydotool.enable = true;

              systemd.services.cpu-freq-cap = {
                description = "Enable boost but cap CPU frequency at 3.1GHz";
                wantedBy = [ "multi-user.target" ];

                serviceConfig = {
                  Type = "oneshot";
                  RemainAfterExit = true;
                  ExecStart = pkgs.writeShellScript "cpu-freq-cap" ''
                    echo 1 > /sys/devices/system/cpu/cpufreq/boost
                    for cpu in /sys/devices/system/cpu/cpu*/cpufreq; do
                      echo performance > "$cpu/scaling_governor"
                      echo 2900000 > "$cpu/scaling_max_freq"
                    done
                  '';
                };
              };

              environment.systemPackages = with pkgs; [
                git
                nwg-look
                ydotool
                rustdesk
                gtk3
                ffmpeg
                neovim
                pciutils
                materialgram
                inputs.prismlauncher-cracked.packages.${pkgs.stdenv.hostPlatform.system}.prismlauncher
              ];

              users.users.gnu = {
                isNormalUser = true;
                extraGroups = [ "wheel" "ydotool" "input" "networkmanager" "video" ];
              };

              system.stateVersion = "24.11";
            }
          )

          # Home Manager
          home-manager.nixosModules.home-manager
          (
            { pkgs, inputs, ... }:
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "hm-backup";

              home-manager.users.gnu = { pkgs, lib, config, ... }: {
                imports = [
                  chromashell.homeManagerModules.default
                  inputs.wayvibes.nixosModules.default
                ];

                services.wayvibes = {
                  enable = true;
                  soundpack = "${inputs.wayvibes}/soundpacks/nk-cream";
                  volume = 2;
                };

                systemd.user.services.wayvibes.Service.ExecStart = lib.mkForce ''
                  ${config.services.wayvibes.package}/bin/wayvibes ${config.services.wayvibes.soundpack} -v ${toString config.services.wayvibes.volume} --device-name "SEMICO   USB Gaming Keyboard "
                '';

                home.packages = [ ];

                home.pointerCursor = {
                  name = "Bibata-Material-Cloud";
                  size = 40;
                  package = pkgs.runCommand "bibata-material-cloud" { } ''
                    mkdir -p $out/share/icons
                    ln -s /home/gnu/.local/share/icons/bibata-material-v1.0.0/Bibata-Material-Cloud $out/share/icons/Bibata-Material-Cloud
                  '';
                  gtk.enable = true;
                  x11.enable = true;
                };

                programs.chromashell = {
                  enable = true;

                  browser = {
                    app = "zen";
                    manage = true;
                  };

                  editor = {
                    app = "vscode";
                    manage = true;
                  };

                  comms = {
                    app = "legcord";
                    manage = true;
                  };

                  music = {
                    app = "spicetify";
                    manage = true;
                  };
                };

                home.stateVersion = "24.11";
              };
            }
          )
        ];
      };
    };
}
