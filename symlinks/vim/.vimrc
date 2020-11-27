let mapleader = ' '

call plug#begin('~/.vim/plugged')

Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'editorconfig/editorconfig-vim'

Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat' "使.能重複上次

Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-fugitive'
Plug 'mg979/vim-visual-multi', {'branch': 'master'} "多光標
Plug 'Yggdroot/LeaderF', { 'do': './install.sh' } "模糊搜尋
Plug 'brooth/far.vim' " 批次修改
Plug 'tpope/vim-abolish' "搜尋替換加強版
Plug 'nathanaelkane/vim-indent-guides' "縮排顯示
Plug 'wincent/ferret' "多檔案修改

" theme
Plug 'drewtempelmeyer/palenight.vim'
" Plug 'itchyny/lightline.vim'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" highlight
Plug 'pangloss/vim-javascript' "javascript
Plug 'mxw/vim-jsx'
" Plug 'numirias/semshi', {'do': ':UpdateRemotePlugins'} " python
Plug 'evanleck/vim-svelte', {'branch': 'main'}
Plug 'iloginow/vim-stylus'

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
set backup

set undodir=~/.vim/.undo//
set backupdir=~/.vim/.backup//
set directory=~/.vim/.swp//

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

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1
if !has('gui_running')
	let g:indent_guides_auto_colors = 0
	hi IndentGuidesEven ctermbg = 238
	hi IndentGuidesOdd ctermbg = 236
endif

" Leader F
let g:Lf_UseCache = 0                                                                      
let g:Lf_UseVersionControlTool = 0
let g:Lf_IgnoreCurrentBufferName = 1
" popup mode          
let g:Lf_WindowPosition = 'popup'     
let g:Lf_PreviewInPopup = 1          
let g:Lf_PreviewResult = {'Function': 0, 'BufTag': 0 }

" vim-airline
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#formatter = 'unique_tail'

" =============================================================
" Use tab for trigger completion with characters ahead and navigate.
" NOTE: Use command ':verbose imap <tab>' to make sure tab is not mapped by
" other plugin before putting this into your config.
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

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

nmap <leader>l :lopen<CR>
nmap <leader>n :CocCommand explorer<CR>
nmap <leader>f :GFiles<CR>
" nmap <leader>f :CocList gfiles<CR>
nmap <leader>g :Rg<CR>
" nmap <leader>g :Leaderf rg<CR>


nnoremap <leader>Fa :FlutterRun<cr>
nnoremap <leader>Fq :FlutterQuit<cr>
nnoremap <leader>Fr :FlutterHotReload<cr>
nnoremap <leader>FR :FlutterHotRestart<cr>
nnoremap <leader>Fd :FlutterVisualDebug<cr>
nnoremap <leader>Fo :sp __Flutter_Output__<cr>
nnoremap <leader>FO :tabe __Flutter_Output__<cr>

imap jk <esc>
