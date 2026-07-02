# Recyclarr syncs TRaSH-guide quality profiles/custom formats into Radarr and
# Sonarr over their APIs. API keys are read at runtime from root-owned files via
# systemd LoadCredential (the `_secret` references), so they never enter the Nix
# store. Create those files per the runbook after Radarr/Sonarr first-run.
_: {
  services.recyclarr = {
    enable = true;
    schedule = "daily";
    configuration = {
      radarr.movies = {
        base_url = "http://localhost:7878";
        api_key._secret = "/var/lib/recyclarr-secrets/radarr-api_key";
      };
      sonarr.tv = {
        base_url = "http://localhost:8989";
        api_key._secret = "/var/lib/recyclarr-secrets/sonarr-api_key";
      };
    };
  };
}
