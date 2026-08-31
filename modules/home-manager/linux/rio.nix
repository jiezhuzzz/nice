_: {
  programs.rio.settings.bindings.keys = [
    {
      key = "c";
      "with" = "super";
      action = "copy";
    }
    {
      key = "v";
      "with" = "super";
      action = "paste";
    }
    {
      key = "t";
      "with" = "super";
      action = "createtab";
    }
    {
      key = "w";
      "with" = "super";
      action = "closesplitortab";
    }
    {
      key = "n";
      "with" = "super";
      action = "createwindow";
    }
    {
      key = "q";
      "with" = "super";
      action = "quit";
    }
  ];
}
