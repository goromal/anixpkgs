{ pkgs, config, lib, ... }:
with pkgs; {
  programs.vim = {
    enable = true;
    extraConfig = ''
      if has('gui_running')
          set guifont=Iosevka
      endif
      set expandtab
      " open NERDTree automatically if no file specified
      "autocmd StdinReadPre * let s:std_in=1
      "autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
      " open NERDTree on Ctrl-n
      map <C-n> :NERDTreeToggle<CR>
      set wildignore+=*/node_modules/*,_site,*/__pycache__/,*/venv/*,*/target/*,*/.vim$,\~$,*/.log,*/.aux,*/.cls,*/.aux,*/.bbl,*/.blg,*/.fls,*/.fdb*/,*/.toc,*/.out,*/.glo,*/.log,*/.ist,*/.fdb_latexmk
      set encoding=utf-8
      set termguicolors
      set background=dark
      let g:mix_format_on_save = 1
      let g:mix_format_options = '--check-equivalent'
    '';
    settings = { number = true; };
    plugins = with vimPlugins; [
      vim-elixir
      sensible
      vim-airline
      The_NERD_tree
      fugitive
      vim-gitgutter
      YouCompleteMe
      vim-abolish
      command-t
    ];
  };
}
