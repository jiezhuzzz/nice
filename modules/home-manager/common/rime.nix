{...}: {
  # Set 小鹤双拼 (from rime-ice) as the active Rime schema.
  xdg.dataFile."fcitx5/rime/default.custom.yaml".text = ''
    patch:
      schema_list:
        - schema: double_pinyin_flypy
  '';
}
