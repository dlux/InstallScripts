set number
set colorcolumn=80
set tabstop=4
set expandtab
set fileformat=unix

" Remember cursor position
if has("autocmd")
  au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif
endif

" To see EOL '$' uncomment next line
"set list
" To see ^M return caracters. fix with dos2unix cmd
":e ++ff=unix
