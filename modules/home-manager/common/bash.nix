{pkgs, ...}: {
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      source ${pkgs.blesh}/share/blesh/ble.sh --attach=prompt
    '';
  };

  xdg.configFile."blesh/init.sh".text = ''
    # Force truecolor — Ghostty supports it but COLORTERM isn't always set
    bleopt term_true_colors=semicolon

    # Catppuccin Frappé palette
    ble-face -s syntax_default           'fg=#c6d0f5'
    ble-face -s syntax_command           'fg=#8caaee'
    ble-face -s syntax_quoted            'fg=#a6d189'
    ble-face -s syntax_quotation         'fg=#a6d189'
    ble-face -s syntax_expr              'fg=#ef9f76'
    ble-face -s syntax_error             'fg=#e78284,bg=#303446'
    ble-face -s syntax_varname           'fg=#eebebe'
    ble-face -s syntax_delimiter         'fg=#949cbb'
    ble-face -s syntax_param_expansion   'fg=#eebebe'
    ble-face -s syntax_history_expansion 'fg=#e5c890'
    ble-face -s syntax_function_name     'fg=#8caaee'
    ble-face -s syntax_comment           'fg=#737994'
    ble-face -s syntax_glob              'fg=#ef9f76'
    ble-face -s syntax_brace             'fg=#ca9ee6'
    ble-face -s syntax_tilde             'fg=#f4b8e4'
    ble-face -s syntax_document          'fg=#a6d189'
    ble-face -s syntax_document_begin    'fg=#ef9f76'

    ble-face -s command_builtin_dot 'fg=#85c1dc'
    ble-face -s command_builtin     'fg=#85c1dc'
    ble-face -s command_alias       'fg=#a6d189'
    ble-face -s command_function    'fg=#8caaee'
    ble-face -s command_file        'fg=#8caaee'
    ble-face -s command_keyword     'fg=#ca9ee6'
    ble-face -s command_jobs        'fg=#ef9f76'
    ble-face -s command_directory   'fg=#ef9f76,underline'

    ble-face -s filename_directory  'fg=#8caaee,underline'
    ble-face -s filename_link       'fg=#81c8be,underline'
    ble-face -s filename_orphan     'fg=#e78284,underline'
    ble-face -s filename_executable 'fg=#a6d189'
    ble-face -s filename_url        'fg=#85c1dc,underline'

    ble-face -s auto_complete       'fg=#737994'
    ble-face -s region              'bg=#414559'
    ble-face -s region_target       'fg=#ef9f76,bg=#51576d'
    ble-face -s region_match        'fg=#ef9f76,bg=#51576d'
  '';
}
