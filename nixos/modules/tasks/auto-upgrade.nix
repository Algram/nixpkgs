{ config, lib, pkgs, ... }:

with lib;

let cfg = config.system.autoUpgrade;

in {

  options = {

    system.autoUpgrade = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Whether to periodically upgrade NixOS to the latest
          version. If enabled, a systemd timer will run
          <literal>nixos-rebuild switch --upgrade</literal> once a
          day.
        '';
      };

      flake = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "github:kloenk/nix";
        description = ''
          The Flake URI of the NixOS configuration to build.
          Disables the option <option>system.autoUpgrade.channel</option>.
        '';
      };

      channel = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "https://nixos.org/channels/nixos-14.12-small";
        description = ''
          The URI of the NixOS channel to use for automatic
          upgrades. By default, this is the channel set using
          <command>nix-channel</command> (run <literal>nix-channel
          --list</literal> to see the current value).
        '';
      };

      flags = mkOption {
        type = types.listOf types.str;
        default = [ ];
        example = [
          "-I"
          "stuff=/home/alice/nixos-stuff"
          "--option"
          "extra-binary-caches"
          "http://my-cache.example.org/"
        ];
        description = ''
          Any additional flags passed to <command>nixos-rebuild</command>.

          If you are using flakes and use a local repo you can add
          <command>[ "--update-input" "nixpkgs" "--commit-lock-file" ]</command>
          to update nixpkgs.
        '';
      };

      dates = mkOption {
        default = "04:40";
        type = types.str;
        description = ''
          Specification (in the format described by
          <citerefentry><refentrytitle>systemd.time</refentrytitle>
          <manvolnum>7</manvolnum></citerefentry>) of the time at
          which the update will occur.
        '';
      };

      allowReboot = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Reboot the system into the new generation instead of a switch
          if the new generation uses a different kernel, kernel modules
          or initrd than the booted system.
          See <option>rebootWindow</option> for configuring the times at which a reboot is allowed.
        '';
      };

      randomizedDelaySec = mkOption {
        default = "0";
        type = types.str;
        example = "45min";
        description = ''
          Add a randomized delay before each automatic upgrade.
          The delay will be chosen between zero and this value.
          This value must be a time span in the format specified by
          <citerefentry><refentrytitle>systemd.time</refentrytitle>
          <manvolnum>7</manvolnum></citerefentry>
        '';
      };

      rebootWindow = mkOption {
        description = ''
          Define a lower and upper time value (in HH:MM format) which
          constitute a time window during which reboots are allowed after an upgrade.
          This option only has an effect when <option>allowReboot</option> is enabled.
          The default value of <literal>null</literal> means that reboots are allowed at any time.
        '';
        default = null;
        example = { lower = "01:00"; upper = "05:00"; };
        type = with types; nullOr (submodule {
          options = {
            lower = mkOption {
              description = "Lower limit of the reboot window";
              type = types.strMatching "[[:digit:]]{2}:[[:digit:]]{2}";
              example = "01:00";
            };

            upper = mkOption {
              description = "Upper limit of the reboot window";
              type = types.strMatching "[[:digit:]]{2}:[[:digit:]]{2}";
              example = "05:00";
            };
          };
        });
      };

    };

  };

  config = lib.mkIf cfg.enable {

    assertions = [{
      assertion = !((cfg.channel != null) && (cfg.flake != null));
      message = ''
        The options 'system.autoUpgrade.channels' and 'system.autoUpgrade.flake' cannot both be set.
      '';
    }];

    system.autoUpgrade.flags = (if cfg.flake == null then
        [ "--no-build-output" ] ++ optionals (cfg.channel != null) [
          "-I"
          "nixpkgs=${cfg.channel}/nixexprs.tar.xz"
        ]
      else
        [ "--flake ${cfg.flake}" ]);

    systemd.services.nixos-upgrade = {
      description = "NixOS Upgrade";

      restartIfChanged = false;
      unitConfig.X-StopOnRemoval = false;

      serviceConfig.Type = "oneshot";

      environment = config.nix.envVars // {
        inherit (config.environment.sessionVariables) NIX_PATH;
        HOME = "/root";
      } // config.networking.proxy.envVars;

      path = with pkgs; [
        coreutils
        gnutar
        xz.bin
        gzip
        gitMinimal
        config.nix.package.out
        config.programs.ssh.package
      ];

      script = let
        nixos-rebuild = "${config.system.build.nixos-rebuild}/bin/nixos-rebuild";
        date     = "${pkgs.coreutils}/bin/date";
        readlink = "${pkgs.coreutils}/bin/readlink";
        shutdown = "${pkgs.systemd}/bin/shutdown";
        upgradeFlag = optional (cfg.channel == null) "--upgrade";
      in if cfg.allowReboot then ''
        ${nixos-rebuild} boot ${toString (cfg.flags ++ upgradeFlag)}
        booted="$(${readlink} /run/booted-system/{initrd,kernel,kernel-modules})"
        built="$(${readlink} /nix/var/nix/profiles/system/{initrd,kernel,kernel-modules})"

        ${optionalString (cfg.rebootWindow != null) ''
          current_time="$(${date} +%H:%M)"

          lower="${cfg.rebootWindow.lower}"
          upper="${cfg.rebootWindow.upper}"

          if [[ "''${lower}" < "''${upper}" ]]; then
            if [[ "''${current_time}" > "''${lower}" ]] && \
               [[ "''${current_time}" < "''${upper}" ]]; then
              do_reboot="true"
            else
              do_reboot="false"
            fi
          else
            # lower > upper, so we are crossing midnight (e.g. lower=23h, upper=6h)
            # we want to reboot if cur > 23h or cur < 6h
            if [[ "''${current_time}" < "''${upper}" ]] || \
               [[ "''${current_time}" > "''${lower}" ]]; then
              do_reboot="true"
            else
              do_reboot="false"
            fi
          fi
        ''}

        if [ "''${booted}" = "''${built}" ]; then
          ${nixos-rebuild} switch ${toString cfg.flags}
        ${optionalString (cfg.rebootWindow != null) ''
          elif [ "''${do_reboot}" != true ]; then
            echo "Outside of configured reboot window, skipping."
        ''}
        else
          ${shutdown} -r +1
        fi
      '' else ''
        ${nixos-rebuild} switch ${toString (cfg.flags ++ upgradeFlag)}
      '';

      startAt = cfg.dates;
    };

    systemd.timers.nixos-upgrade.timerConfig.RandomizedDelaySec =
      cfg.randomizedDelaySec;

  };

}

