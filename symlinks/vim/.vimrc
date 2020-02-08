let mapleader = ' '

call plug#begin('~/.vim/plugged')
" Plug '~/.vim/plugged/before'

Plug 'vim-scripts/BufOnly.vim'
Plug 'ekalinin/Dockerfile.vim', { 'for': 'dockerfile' }
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --clang-completer --rust-completer' }
Plug 'slashmili/alchemist.vim', { 'for': 'elixir' }
Plug 'wincent/ferret'

" Asynchronous linting/fixing for Vim and Language Server Protocol (LSP) integration
Plug 'w0rp/ale'
" Plug 'skywind3000/asyncrun.vim'
Plug 'jiangmiao/auto-pairs'
Plug 'rhysd/devdocs.vim'
Plug 'editorconfig/editorconfig-vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' } | Plug 'junegunn/fzf.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'godlygeek/tabular'
Plug 'majutsushi/tagbar'
Plug 'SirVer/ultisnips'
Plug 'PeterRincker/vim-argumentative'
Plug 'tpope/vim-abolish'
Plug 'alvan/vim-closetag', { 'for': ['html', 'javascript,jsx', 'xhtml'] }
Plug 'hail2u/vim-css3-syntax', { 'for': 'css' }
Plug 'easymotion/vim-easymotion'
Plug 'ludovicchabant/vim-gutentags'
Plug 'moll/vim-node', { 'for': 'jsx' }
Plug 'tpope/vim-obsession', { 'on':  'Obsession' }
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-rhubarb'

Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'

Plug 'tpope/vim-sensible'
" Plug 'vitalk/vim-shebang'
" Plug 'tpope/vim-sleuth'
" Plug 'honza/vim-snippets'
Plug 'tpope/vim-surround'
" Plug 'pedrohdz/vim-yaml-folds', { 'for': 'yaml' }

Plug 'scrooloose/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'

Plug 'nathanaelkane/vim-indent-guides'
Plug 'drewtempelmeyer/palenight.vim'
Plug 'itchyny/lightline.vim'

Plug 'lilydjwg/colorizer'

" Plug 'altercation/vim-colors-solarized'
" Plug 'flazz/vim-colorschemes'

Plug 'ervandew/supertab'

Plug 'posva/vim-vue'
Plug 'terryma/vim-multiple-cursors'
Plug 'scrooloose/syntastic'

Plug 'codeindulgence/vim-tig'
" Plug '~/.vim/plugged/after'
"
" Plug 'zxqfl/tabnine-vim'
call plug#end()

" make YCM compatible with UltiSnips (using supertab)
let g:ycm_key_list_select_completion = ['<C-n>', '<Down>']
let g:ycm_key_list_previous_completion = ['<C-p>', '<Up>']
let g:SuperTabDefaultCompletionType = '<C-n>'
let g:ycm_autoclose_preview_window_after_completion = 1

" better key bindings for UltiSnipsExpandTrigger
let g:UltiSnipsExpandTrigger = "<tab>"
let g:UltiSnipsJumpForwardTrigger = "<tab>"
let g:UltiSnipsJumpBackwardTrigger = "<s-tab>"

let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_guide_size = 1

let g:lightline = { 'colorscheme': 'palenight' }

" gutentags搜索工程目录的标志，碰到这些文件/目录名就停止向上一级目录递归 "
let g:gutentags_project_root = ['.root', '.svn', '.git', '.project']

" 所生成的数据文件的名称 "
let g:gutentags_ctags_tagfile = '.tags'

" 将自动生成的 tags 文件全部放入 ~/.cache/tags 目录中，避免污染工程目录 "
let s:vim_tags = expand('~/.cache/tags')
let g:gutentags_cache_dir = s:vim_tags
" 检测 ~/.cache/tags 不存在就新建 "
if !isdirectory(s:vim_tags)
   silent! call mkdir(s:vim_tags, 'p')
endif

" 配置 ctags 的参数 "
let g:gutentags_ctags_extra_args = ['--fields=+niazS', '--extra=+q']
let g:gutentags_ctags_extra_args += ['--c++-kinds=+pxI']
let g:gutentags_ctags_extra_args += ['--c-kinds=+px']
" let g:indent_guides_auto_colors = 0

let g:syntastic_javascript_checkers = ['eslint']

if has("gui_running")
    set go=aAce
    set transparency=10
    " set guifont=Monaco:h14
    set showtabline=2
    set columns=170
    set lines=53

    set macligatures
    set guifont=Fira\ Code\ Medium:h14

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

" if (has("termguicolors"))
"   set termguicolors
" endif

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

" vim-vue
let g:vue_disable_pre_processors=1
autocmd FileType vue syntax sync fromstart
" autocmd BufRead,BufNewFile *.vue setlocal filetype=vue.html.javascript.css.less.pug

nmap <leader>l :lopen<CR>
nmap <leader>n :NERDTreeToggle<CR>
nmap <leader>f :GFiles<CR>
nmap <leader>g :Rg<CR>

