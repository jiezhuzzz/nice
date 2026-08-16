# Xuewen — self-hosted paper manager (github:jiezhuzzz/xuewen). No nixpkgs
# package: the flake input carries both the build and this service module.
# Tailnet-only — binds 127.0.0.1, opens no firewall port, caddy is the only way
# in. 8087 because metatube holds 8080 and stirling/glance/karakeep/searx/
# miniflux take 8082-8086.
#
# The web UI has NO authentication and its mutating endpoints answer anyone who
# reaches them, so the tailnet is the entire access control here — never give
# this a LAN port or a non-loopback bind.
#
# Library, SQLite database and search index live under /var/lib/xuewen; drop
# PDFs into /var/lib/xuewen/inbox to ingest them.
#
# Every optional feature is turned on here except GROBID (`grobid_url`), which
# has no nixpkgs package and would need its own ~1.3GB OCI container to serve
# the single call xuewen makes of it — processHeaderDocument, a title/abstract/
# author fallback for PDFs that DOI/arXiv/Crossref resolution can't identify.
#
# Each feature is gated on the *presence* of its config section, not on an
# enable flag: an absent section means off. Empty attrsets below are therefore
# meaningful — `summary = {}` renders `[ai.summary]`, which switches summaries
# on and inherits the endpoint and model from `[ai]`.
#
# LLM traffic goes through the local LiteLLM gateway exactly like karakeep,
# with two exceptions that reach their provider directly and so need real keys
# from environmentFile: Agent Ask (the Claude Code / Codex SDKs) and DeepL.
#
# Semantic search needs a Qdrant server; it runs as an OCI container at the
# bottom of this file rather than services.qdrant, for the toolchain reason
# documented there.
{
  config,
  inputs,
  ...
}: {
  imports = [inputs.xuewen.nixosModules.default];

  services.xuewen = {
    enable = true;
    port = 8087;

    settings = {
      # Sent as the User-Agent on Crossref/arXiv metadata lookups, which puts
      # them in Crossref's polite pool (better rate limits, and they mail you
      # before blocking rather than after).
      contact_email = "jiezhu@uchicago.edu";

      # Institutional proxy for fetching paywalled PDFs by URL/DOI: xuewen
      # percent-encodes the target URL and appends it to this prefix. The
      # rotating session cookie deliberately does NOT live here — set it in the
      # web UI's "Institutional access" panel, or with
      # `xuewen proxy-cookie --set '<cookie>'`.
      proxy.login_url = "https://proxy.uchicago.edu/login?url=";

      # Semantic search rides on the Qdrant instance enabled below. Upstream's
      # default is http://localhost:6333, which also resolves to ::1 — Qdrant
      # only binds 127.0.0.1, so name the literal and skip the dead attempt.
      # (index_dir is set by the module under dataDir; recursiveUpdate is deep,
      # so naming one key here leaves the other default intact.)
      search.qdrant_url = "http://127.0.0.1:6333";

      # Daily arXiv recommendations, surfaced at /api/daily for the Glance
      # dashboard. New announcements are scored against the embeddings of the
      # library's own titles+abstracts, so this needs [ai.embedding]; [ai.daily]
      # below writes the blurbs. run_at is UTC wall time and defaults to 09:00 —
      # 04:00 America/Chicago, comfortably after arXiv's 20:00 ET announcement —
      # as do max_papers (20 kept per day) and retention_days (14).
      daily.categories = [
        "cs.CR" # cryptography and security
        "cs.SE" # software engineering
        "cs.LG" # machine learning
        "cs.CL" # computation and language
        "cs.AI" # artificial intelligence
        "cs.OS" # operating systems
        "cs.DC" # distributed, parallel and cluster computing
        "cs.PL" # programming languages
      ];

      # Translate-on-selection in the PDF reader. The feature switches on with
      # the first provider ([ai.translate] below, and/or this); this section only
      # carries defaults. `provider` is left unset, which resolves to the LLM
      # when both are available — set it to "deepl" to flip the default.
      # `trigger` is left at upstream's "auto" and is only a seed for the
      # reader's own Auto/Manual toggle.
      translate = {
        target_lang = "zh"; # translate INTO Simplified Chinese
        # DeepL talks to api-free.deepl.com on the free plan and api.deepl.com
        # on Pro; a free-tier key is the one that ends in ":fx". Switch to "pro"
        # if the key in the secret below is a paid one, or DeepL answers 403.
        deepl = {
          api_key_env = "DEEPL_API_KEY";
          plan = "free";
        };
      };

      ai = {
        # LiteLLM speaks the OpenAI API and holds both provider keys (litellm.nix,
        # :4000). It has no master key (localhost-only), so any non-empty string
        # satisfies the client — a placeholder, not a secret. If LiteLLM ever gets
        # a master key, move this to api_key_env + environmentFile.
        base_url = "http://127.0.0.1:4000/v1";
        api_key = "litellm-local";
        # Default for the uses below — all of them are high-volume, so the cheap
        # model. The name must match litellm.nix's model_list.
        model = "Claude Haiku 4.5";
        summary = {}; # per-paper library summaries
        citations = {}; # parses only the references the pattern matcher misses
        daily = {}; # blurbs for the arXiv feed above
        translate = {}; # LLM provider for translate-on-selection

        # Vectors behind semantic search and the daily feed's interest profile.
        # text-embedding-3-small is already in litellm.nix's model_list (karakeep
        # uses it too), so this inherits base_url/api_key above and only names
        # the model. dims must match what the API returns or the embedder aborts
        # — 1536 is text-embedding-3-small's native width. Changing either means
        # dropping the Qdrant collection and re-embedding the library.
        embedding = {
          model = "text-embedding-3-small";
          dims = 1536;
        };

        # Agent Ask — the reader's Ask tab, and the gate on the code-attach
        # endpoint (PUT /api/papers/{id}/code clones into
        # <library_root>/agent/<paper_id>/repo). Unlike everything above it does
        # NOT go through LiteLLM: the Claude Code and Codex SDKs talk to
        # Anthropic and OpenAI directly, with the keys from environmentFile
        # below. Both SDKs ship inside the packaged agent-runner, so neither
        # backend needs a CLI on PATH. Models left unset — each SDK's own
        # default. Upstream's module points .runner at that agent-runner and
        # drops MemoryDenyWriteExecute (node's JIT needs writable-then-executable
        # pages).
        agent = {
          claude_code = {};
          codex = {};
        };
      };
    };

    # ANTHROPIC_API_KEY and OPENAI_API_KEY for the two agent SDKs, plus
    # DEEPL_API_KEY for the DeepL translator. Same encrypted file LiteLLM reads,
    # decrypted under its own name so this module doesn't depend on litellm.nix
    # being imported. DeepL resolves its key per request rather than at startup,
    # so a file still missing DEEPL_API_KEY costs only the DeepL translations —
    # everything else, translate-via-LLM included, keeps working.
    environmentFile = config.age.secrets.xuewen-provider-keys.path;
  };

  # Vector store for [ai.embedding] above — xuewen is its only consumer, so it
  # lives here rather than in a module of its own.
  #
  # Deliberately NOT services.qdrant. nixpkgs' rustc 1.97.1 is linked against
  # LLVM 21.1.8, whose llvm.x86.avx512.vpdpbusd.512 takes three <16 x i32>
  # operands, while the stdarch bundled in that same rustc still declares the
  # pre-LLVM-21 (<16 x i32>, <64 x i8>, <64 x i8>) form. Any crate calling
  # _mm512_dpbusd_epi32 therefore fails to codegen, and qdrant's
  # lib/quantization calls it — so the native build dies, and hydra fails
  # identically, which is why qdrant never substitutes and lands in "will be
  # built". There is no escape hatch: the intrinsic sits behind
  # #[target_feature(enable = "avx512vnni")], so -C target-feature=-avx512vnni
  # does not suppress it, the derivation exposes no cargo feature for the SIMD
  # path, and nixpkgs carries no second rust toolchain to override with (only
  # rust_1_97). Reverting the flake.lock bump does not help either — the
  # committed nixpkgs pins the same rustc, LLVM and qdrant.
  #
  # The upstream image is the same 1.18.2, prebuilt, so nothing is lost but the
  # native unit. Revisit services.qdrant once rustc and LLVM agree again.
  #
  # Pinned by digest like metatube; bump deliberately (pull the tag, then
  # `podman inspect --format '{{index .RepoDigests 0}}'`). Setting `backend`
  # here too is safe — the option merges equal definitions, and this module
  # must not depend on metatube.nix being imported.
  virtualisation.oci-containers = {
    backend = "podman";
    containers.qdrant = {
      image = "docker.io/qdrant/qdrant@sha256:75eab8c4ba42096724fdcfde8b4de0b5713d529dde32f285a1f86fdcb2c9e50c";
      # Only the HTTP REST port: xuewen drives Qdrant over reqwest against
      # /collections/xuewen/points, never the :6334 gRPC one. Published to
      # loopback, so the container's own 0.0.0.0 bind stays inside its netns.
      ports = ["127.0.0.1:6333:6333"];
      volumes = ["/var/lib/qdrant:/qdrant/storage"];
      environment = {
        # Matches what the nixpkgs module set for us.
        QDRANT__TELEMETRY_DISABLED = "true";
        # Default is /qdrant/snapshots, outside the volume above — keep
        # snapshots on persistent storage rather than in the container layer.
        QDRANT__STORAGE__SNAPSHOTS_PATH = "/qdrant/storage/snapshots";
      };
    };
  };

  # The generated container unit runs as root, so StateDirectory creates
  # /var/lib/qdrant as persistent root-owned storage before Podman resolves the
  # bind mount above.
  systemd.services.podman-qdrant.serviceConfig = {
    StateDirectory = "qdrant";
    StateDirectoryMode = "0750";
  };

  age.secrets.xuewen-provider-keys = {
    file = ../../secrets/llm/provider-keys.age;
    mode = "0400";
  };
}
