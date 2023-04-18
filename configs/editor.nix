{
  config = {
    vim.languages = {
      enableLSP = true;
      enableTreesitter = true;
      nix.enable = true;
      rust.enable = true;
      clang.enable = true;
      markdown.enable = true;

      rust.lsp.opts = ''
        ["rust-analyzer"] = {
          check = {
            targets = "x86_64-mustang-linux-gnu",
            extraArgs = { "-Zbuild-std=core,alloc,test,std" },
            allTargets = false,
          },
        },
      '';
    };
    vim.lsp = {
      enable = true;
      lightbulb.enable = true;
      lspSignature.enable = true;
      trouble.enable = true;
      lspkind.enable = true;
      nvimCodeActionMenu.enable = true;
      formatOnSave = true;
    };
    vim.statusline.lualine.enable = true;
    vim.visuals = {
      enable = true;
      nvimWebDevicons.enable = true;
      indentBlankline = {
        enable = true;
        fillChar = null;
        eolChar = null;
        showCurrContext = true;
      };
      cursorWordline = {
        enable = true;
        lineTimeout = 0;
      };
    };

    vim.theme = {
      enable = true;
      name = "onedark";
      style = "darker";
    };
    vim.autopairs.enable = true;
    vim.autocomplete = {
      enable = true;
      type = "nvim-cmp";
    };
    vim.filetree.nvimTreeLua.enable = true;
    vim.tabline.nvimBufferline.enable = true;
    vim.telescope = {
      enable = true;
    };
    vim.treesitter = {
      context.enable = true;
    };
    vim.keys = {
      enable = true;
      whichKey.enable = true;
    };
    vim.git = {
      enable = true;
      gitsigns.enable = true;
    };
  };
}
