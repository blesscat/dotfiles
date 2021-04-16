let mapleader = ' '

call plug#begin('~/.vim/plugged')

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'editorconfig/editorconfig-vim'

Plug 'tpope/vim-surround' "快速操作配對字符 例如ds' 刪除前後的'
Plug 'tpope/vim-repeat' "使.能重複上次

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive'
Plug 'mg979/vim-visual-multi', {'branch': 'master'} "多光標
Plug 'Yggdroot/LeaderF', { 'do': ':LeaderfInstallCExtension' } "模糊搜尋
Plug 'brooth/far.vim' " 批次修改
Plug 'tpope/vim-abolish' "搜尋替換加強版
Plug 'nathanaelkane/vim-indent-guides' "縮排顯示
Plug 'wincent/ferret' "多檔案修改

Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins'}

" theme
Plug 'drewtempelmeyer/palenight.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" highlight
Plug 'pangloss/vim-javascript' "javascript
Plug 'mxw/vim-jsx' "jsx
Plug 'iloginow/vim-stylus' "stylus
Plug 'posva/vim-vue' "vue
Plug 'ap/vim-css-color' "css color
Plug 'sirtaj/vim-openscad' "openscad
Plug 'peitalin/vim-jsx-typescript' "react jsx 
Plug 'leafgarland/typescript-vim' 

" Plug 'w0rp/ale'
Plug 'burner/vim-svelte'

Plug 'neoclide/jsonc.vim' "jsonc

" dart
" Plug 'natebosch/vim-lsc'
" Plug 'natebosch/vim-lsc-dart'
Plug 'dart-lang/dart-vim-plugin'

call plug#end()

if has("gui_running")
    set go=aAce
    set transparency=10
    " set guifont=Monaco:h14
    set showtabline=2
    set columns=170
    set lines=53

    set macligatures
    set guifont=FiraCode\ Nerd\ font:h14

    noremap <D-1> :tabn 1<CR>
    noremap <D-2> :tabn 2<CR>
    noremap <D-3> :tabn 3<CR>
    noremap <D-4> :tabn 4<CR>
    noremap <D-5> :tabn 5<CR>
    noremap <D-6> :tabn 6<CR>
    noremap <D-7> :tabn 7<CR>
    noremap <D-8> :tabn 8<CR>
    noremap <D-9> :tabn 9<CR>
    " Command-0 goes to the last tab
    noremap <D-0> :tablast<CR>
endif


set undofile
" set backup

set undodir=~/.vim/.undo//
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//
set tags=tags;
set autochdir

function! GuiTabLabel()
    return bufname(winbufnr(1))
endfunction


set guitablabel=%{GuiTabLabel()}

" set ignorecase
set smartcase

set autoindent
set number
set incsearch
set hlsearch

" syntax enable
set background=dark
colorscheme palenight

" autocmd vimenter * NERDTree
autocmd FileType css set omnifunc=csscomplete#CompleteCSS

let g:lightline = { 'colorscheme': 'palenight' }


" vim-indent-guides
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1

if !has('gui_running')
	let g:indent_guides_auto_colors = 0
	hi IndentGuidesEven ctermbg = 238
	hi IndentGuidesOdd ctermbg = 236
endif

" Leader F
let g:Lf_UseCache = 1
let g:Lf_UseVersionControlTool = 0
let g:Lf_IgnoreCurrentBufferName = 1
" popup mode          
" let g:Lf_WindowPosition = 'popup'     
let g:Lf_PreviewInPopup = 1          
" let g:Lf_PreviewResult = {'Function': 0, 'BufTag': 0 }

" vim-airline
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

" vim-svelte-plugin
let g:vim_svelte_plugin_load_full_syntax = 1

" ale
let g:ale_linter_aliases = {'svelte': ['css', 'javascript']}
let g:ale_linters = {'svelte': ['stylelint', 'eslint']}


noremap <leader>y "+y
noremap <leader>p "+p

noremap <leader>1 1gt
noremap <leader>2 2gt
noremap <leader>3 3gt
noremap <leader>4 4gt
noremap <leader>5 5gt
noremap <leader>6 6gt
noremap <leader>7 7gt
noremap <leader>8 8gt
noremap <leader>9 9gt
noremap <leader>0 :tablast<cr>

" nmap <leader>l :lopen<CR>
function! CustomLeaderfFile()
	let l:path = system('PWD=$(pwd) echo ${PWD%src*}')
	exec ':Leaderf file ' . path
endfunction

function! CustomLeaderfRg()
	let l:path = system('PWD=$(pwd) echo ${PWD%src*}')
	exec ':Leaderf rg  ' . path
endfunction

nmap <leader>l :CocList<CR>
nmap <leader>n :CocCommand explorer<CR>
" nmap <leader>f :Leaderf file<CR>
nmap <leader>f :call CustomLeaderfFile()<CR>
nmap <leader>g :Leaderf rg<CR>
" nmap <leader>g :call CustomLeaderfRg()<CR>
nmap <leader>m :Leaderf mru<CR>


nnoremap <leader>Fa :FlutterRun<cr>
nnoremap <leader>Fq :FlutterQuit<cr>
nnoremap <leader>Fr :FlutterHotReload<cr>
nnoremap <leader>FR :FlutterHotRestart<cr>
nnoremap <leader>Fd :FlutterVisualDebug<cr>
nnoremap <leader>Fo :sp __Flutter_Output__<cr>
nnoremap <leader>FO :tabe __Flutter_Output__<cr>

imap jk <esc>

source ~/.vimcoc
