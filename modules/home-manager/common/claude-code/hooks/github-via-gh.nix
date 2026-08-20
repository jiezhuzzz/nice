# Guard: GitHub is read through the `gh` CLI, never fetched as a web page.
#
# Fetching a github.com URL is unauthenticated, so private repos 404 and the
# anonymous rate limit applies, and what comes back is the furniture around a
# record rather than the record — a PR without its diff or review threads, a
# file inside a viewer, a run without its logs. `gh` is already logged in and
# returns the thing itself.
#
# Scope is an explicit host list, not *.github.com: docs.github.com,
# github.blog and *.github.io are ordinary pages that `gh` cannot serve and
# must stay fetchable. Keep the list in step with the WebFetch entries in
# settings.nix.
#
# Two entry points over one URL -> command mapping, because the same fetch
# arrives by two routes: `fromUrl` guards the WebFetch tool, `fromCommand`
# catches curl/wget aimed at the same hosts from Bash. Unlike the sibling
# guards this file exports an attribute set rather than one string — the
# mapping is shared, the payload each reads is not.
let
  # Every branch degrades to a `gh api` path, which can serve any
  # REST-reachable URL, so an unrecognised shape still yields a usable command.
  mapper = ''
    github_cli_host() {
      case $1 in
        github.com | www.github.com | api.github.com | gist.github.com | codeload.github.com | raw.githubusercontent.com | gist.githubusercontent.com | objects.githubusercontent.com) return 0 ;;
        *) return 1 ;;
      esac
    }

    url_host() {
      local h=''${1#*://}
      h=''${h%%/*}
      h=''${h%%[?#]*}
      h=''${h#*@}
      h=''${h%%:*}
      printf '%s' "''${h,,}"
    }

    gh_for_url() {
      local host path slug kind id ref start
      local -a seg
      host=$(url_host "$1")
      path=''${1#*://}
      case $path in
        */*) path=''${path#*/} ;;
        *) path="" ;;
      esac
      path=''${path%%[?#]*}
      path=''${path%/}
      IFS=/ read -r -a seg <<<"$path"
      slug=''${seg[0]-}/''${seg[1]-}
      kind=''${seg[2]-}
      id=''${seg[3]-}

      case $host in
        api.github.com)
          printf 'gh api %s' "$path"
          return
          ;;
        gist.github.com | gist.githubusercontent.com)
          printf 'gh gist view %s' "''${seg[1]-''${seg[0]-}}"
          return
          ;;
        raw.githubusercontent.com)
          ref=$kind
          start=3
          if [[ $kind == refs ]]; then
            ref=''${seg[4]-}
            start=5
          fi
          printf "gh api -H 'Accept: application/vnd.github.raw' 'repos/%s/contents/%s?ref=%s'" \
            "$slug" "$(IFS=/; printf '%s' "''${seg[*]:start}")" "$ref"
          return
          ;;
        objects.githubusercontent.com)
          printf 'gh release download <tag> --repo <owner>/<repo> --pattern <asset>'
          return
          ;;
        codeload.github.com)
          printf 'gh repo clone %s, or gh release download --repo %s' "$slug" "$slug"
          return
          ;;
      esac

      case $kind in
        issues)
          if [[ -n $id ]]; then
            printf 'gh issue view %s --repo %s --comments' "$id" "$slug"
          else
            printf 'gh issue list --repo %s' "$slug"
          fi
          ;;
        pull | pulls)
          if [[ -n $id ]]; then
            printf 'gh pr view %s --repo %s --comments (diff: gh pr diff %s --repo %s)' "$id" "$slug" "$id" "$slug"
          else
            printf 'gh pr list --repo %s' "$slug"
          fi
          ;;
        blob | raw)
          printf "gh api -H 'Accept: application/vnd.github.raw' 'repos/%s/contents/%s?ref=%s'" \
            "$slug" "$(IFS=/; printf '%s' "''${seg[*]:4}")" "$id"
          ;;
        tree)
          printf "gh api 'repos/%s/contents/%s?ref=%s'" \
            "$slug" "$(IFS=/; printf '%s' "''${seg[*]:4}")" "$id"
          ;;
        releases)
          case $id in
            download) printf 'gh release download %s --repo %s --pattern %s' "''${seg[4]-}" "$slug" "''${seg[5]-}" ;;
            tag) printf 'gh release view %s --repo %s' "''${seg[4]-}" "$slug" ;;
            latest) printf 'gh release view --repo %s' "$slug" ;;
            ''') printf 'gh release list --repo %s' "$slug" ;;
            *) printf 'gh release view %s --repo %s' "$id" "$slug" ;;
          esac
          ;;
        commit | commits)
          printf 'gh api repos/%s/commits/%s' "$slug" "$id"
          ;;
        compare)
          printf 'gh api repos/%s/compare/%s' "$slug" "$id"
          ;;
        actions)
          if [[ $id == runs && -n ''${seg[4]-} ]]; then
            printf 'gh run view %s --repo %s --log' "''${seg[4]-}" "$slug"
          else
            printf 'gh run list --repo %s' "$slug"
          fi
          ;;
        ''')
          if [[ -n ''${seg[1]-} ]]; then
            printf 'gh repo view %s' "$slug"
          elif [[ -n ''${seg[0]-} ]]; then
            printf 'gh repo list %s' "''${seg[0]-}"
          else
            printf 'gh api <endpoint>'
          fi
          ;;
        *)
          printf 'gh repo view %s, or gh api repos/%s/<endpoint>' "$slug" "$slug"
          ;;
      esac
    }

  '';
in {
  fromCommand =
    mapper
    + ''
      scrubbed=''${cmd//[\'\"\`]/ }
      if [[ "$cmd" =~ $sep(curl|wget|xh|aria2c|http|https|httpie|w3m|lynx)([[:space:]]|$) ]]; then
        read -ra toks <<<"''${scrubbed//$'\n'/ }"
        for tok in ''${toks[@]+"''${toks[@]}"}; do
          if github_cli_host "$(url_host "$tok")"; then
            deny "Fetching GitHub with curl/wget is not how this machine reads it: the request is unauthenticated, so private repos 404 and the anonymous rate limit applies, and an HTML page buries the record you actually want. The gh CLI is installed and already logged in. Use this instead: $(gh_for_url "$tok") — 'gh api <endpoint>' reaches anything else in the REST API (--paginate for lists, --jq to filter), and 'gh release download' / 'gh repo clone' pull files down. Only github.com, api/gist/codeload.github.com and raw/gist/objects.githubusercontent.com are covered: docs.github.com, github.blog and *.github.io are ordinary pages and stay fetchable. git over https is untouched, so 'git clone https://github.com/...' is fine. Do not work around this with a different downloader."
          fi
        done
      fi
    '';

  fromUrl =
    mapper
    + ''
      url=$(jq -r '.tool_input.url // ""' <<<"$input")
      if github_cli_host "$(url_host "$url")"; then
        deny "GitHub is read through the gh CLI here, never fetched as a web page: the fetch is unauthenticated, so private repos 404 and the anonymous rate limit applies, and the HTML hands back the furniture around the record instead of the record — a PR without its diff or review threads, a file inside a viewer, a run without its logs. Use this instead: $(gh_for_url "$url") — 'gh api <endpoint>' reaches anything else in the REST API (--paginate for lists, --jq to filter). Only github.com, api/gist/codeload.github.com and raw/gist/objects.githubusercontent.com are covered: docs.github.com, github.blog and *.github.io are ordinary pages and stay fetchable."
      fi
    '';
}
