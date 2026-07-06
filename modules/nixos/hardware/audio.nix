# PipeWire (ALSA + Pulse) for local playback, plus a console-style "Loudness"
# output that compresses dynamic range and lifts average loudness toward the
# ceiling — so games/media over HDMI feel as loud as an Apple TV / Switch at the
# same TV volume, instead of quiet with wide dynamics.
{pkgs, ...}: {
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;

    # CAPS provides the CompressX2 LADSPA plugin used by the filter-chain below.
    # NixOS pins PipeWire's LADSPA_PATH to a curated buildEnv, so plugins must be
    # added here (a raw file path is NOT searched) — then referenced by name.
    extraLadspaPackages = [pkgs.caps];

    # A "Loudness" virtual sink: CAPS CompressX2 (stereo compressor + saturating
    # limiter) → the HDMI/LG-TV output. Play into this sink (make it the default,
    # or pick it per-app) to get the console-style loudness. It's a saturating
    # limiter, so it lifts loudness without hard-clipping.
    #
    # Tune to taste (all 0..1 unless noted):
    #   threshold ↓  and/or  strength ↑   → more compression (denser, louder)
    #   "gain (dB)" ↑ (-12..36)           → more makeup gain (raw loudness boost)
    #   attack / release                  → how fast it reacts
    # target.object pins the processed output to this box's HDMI node.
    extraConfig.pipewire."99-loudness" = {
      "context.modules" = [
        {
          name = "libpipewire-module-filter-chain";
          flags = ["nofail"];
          args = {
            "node.description" = "Loudness";
            "media.name" = "Loudness";
            "filter.graph" = {
              nodes = [
                {
                  type = "ladspa";
                  name = "compressor";
                  plugin = "caps";
                  label = "CompressX2";
                  control = {
                    "threshold" = 0.4;
                    "strength" = 0.35;
                    "attack" = 0.75;
                    "release" = 0.5;
                    "gain (dB)" = 6.0;
                  };
                }
              ];
              inputs = ["compressor:in.l" "compressor:in.r"];
              outputs = ["compressor:out.l" "compressor:out.r"];
            };
            "capture.props" = {
              "node.name" = "loudness_sink";
              "node.description" = "Loudness (console-style)";
              "media.class" = "Audio/Sink";
              "audio.channels" = 2;
              "audio.position" = ["FL" "FR"];
            };
            "playback.props" = {
              "node.name" = "loudness_output";
              "node.passive" = true;
              "audio.channels" = 2;
              "audio.position" = ["FL" "FR"];
              "target.object" = "alsa_output.pci-0000_c3_00.1.hdmi-stereo-extra1";
            };
          };
        }
      ];
    };
  };
}
