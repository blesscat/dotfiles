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
Plug 'ap/vim-css-color' "css color

Plug 'w0rp/ale'
Plug 'burner/vim-svelte'

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
let g:Lf_UseCache = 0                                                                      
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

" ======================coc.nvim=================================================
" 設定 node 路徑
let g:coc_node_path = "/usr/local/bin/node"
" if hidden is not set, TextEdit might fail.
set hidden

" Some servers have issues with backup files, see #649
set nobackup
set nowritebackup

" Better display for messages
set cmdheight=2

" You will have bad experience for diagnostic messages when it's default 4000.
set updatetime=300

" don't give |ins-completion-menu| messages.
set shortmess+=c

" always show signcolumns
set signcolumn=yes

" 使用 tab 觸發帶有幾個字元的補全並導覽
" 使用指令 ':verbose imap <tab>' 確定 tab 沒有被映射到其他插件
inoremap <silent><expr> <TAB>
      \ pumvisible() ? "\<C-n>" :
      \ <SID>check_back_space() ? "\<TAB>" :
      \ coc#refresh()
inoremap <expr><S-TAB> pumvisible() ? "\<C-p>" : "\<C-h>"

function! s:check_back_space() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" 使用 <c-space> 觸發補全
inoremap <silent><expr> <c-space> coc#refresh()

" 使用 <cr> 確認補全，`<C-g>u` 表示在當前位置斷開撤消鏈
" Coc 僅在確認時做片段和額外編輯
inoremap <expr> <cr> pumvisible() ? "\<C-y>" : "\<C-g>u\<CR>"

" 使用 `[g` 和 `]g` 瀏覽診斷
nmap <silent> [g <Plug>(coc-diagnostic-prev)
nmap <silent> ]g <Plug>(coc-diagnostic-next)

" 重新映射Gotos的鍵
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" 使用 K 在預覽窗口中顯示文檔
nnoremap <silent> K :call <SID>show_documentation()<CR>

function! s:show_documentation()
  if (index(['vim','help'], &filetype) >= 0)
    execute 'h '.expand('<cword>')
  else
    call CocAction('doHover')
  endif
endfunction

" 高亮 symbol 在游標 CursorHold 時
autocmd CursorHold * silent call CocActionAsync('highlight')

" 重新映射以重命名當前單詞
nmap <leader>rn <Plug>(coc-rename)

" 重新映射格式化選定區域
xmap <leader>f  <Plug>(coc-format-selected)
nmap <leader>f  <Plug>(coc-format-selected)

augroup mygroup
  autocmd!
  " 設置 formatexpr 指定的 filetype(s).
  autocmd FileType typescript,json setl formatexpr=CocAction('formatSelected')
  " Update signature help on jump placeholder
  autocmd User CocJumpPlaceholder call CocActionAsync('showSignatureHelp')
augroup end

" 重新映射執行代碼選定區域的操作，例如：當前段落的<leader> aap
xmap <leader>a  <Plug>(coc-codeaction-selected)
nmap <leader>a  <Plug>(coc-codeaction-selected)

" 重新映射代碼執行當前行的操作
nmap <leader>ac  <Plug>(coc-codeaction)
" 修復當前可修復的第一個錯誤修復操作
nmap <leader>qf  <Plug>(coc-fix-current)

" 建立映射給函式文本物件，需要 languageserver 的 document symbols feature
xmap if <Plug>(coc-funcobj-i)
xmap af <Plug>(coc-funcobj-a)
omap if <Plug>(coc-funcobj-i)
omap af <Plug>(coc-funcobj-a)

" 使用 <TAB> 用於選擇範圍，必須 server 支援，像: coc-tsserver, coc-python
nmap <silent> <TAB> <Plug>(coc-range-select)
xmap <silent> <TAB> <Plug>(coc-range-select)

" 使用 `:Format` 格式化當前緩衝
command! -nargs=0 Format :call CocAction('format')

" 使用 `:Fold` 折疊當前緩衝
command! -nargs=? Fold :call     CocAction('fold', <f-args>)

" 使用 `:OR` 用於組織匯入當前緩衝區
command! -nargs=0 OR   :call     CocAction('runCommand', 'editor.action.organizeImport')

" 添加狀態行支持，以便與其他插件集成，查看 `:h coc-status`
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')}

" 使用 CocList
" 顯示所有診斷
nnoremap <silent> <space>a  :<C-u>CocList diagnostics<cr>
" 管理擴充
nnoremap <silent> <space>e  :<C-u>CocList extensions<cr>
" 顯示指令
nnoremap <silent> <space>c  :<C-u>CocList commands<cr>
" 尋找當前文件的 symbol
nnoremap <silent> <space>o  :<C-u>CocList outline<cr>
" 尋找 workspace symbols
nnoremap <silent> <space>s  :<C-u>CocList -I symbols<cr>
" 對下一項執行默認操作。
nnoremap <silent> <space>j  :<C-u>CocNext<CR>
" 對上一項執行默認操作。
nnoremap <silent> <space>k  :<C-u>CocPrev<CR>
" 恢復最新的 coc list
nnoremap <silent> <space>p  :<C-u>CocListResume<CR>

"===============end coc.nvim=============================================

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
nmap <leader>l :CocList<CR>
nmap <leader>n :CocCommand explorer<CR>
" nmap <leader>f :GFiles<CR>
nmap <leader>f :Leaderf file<CR>
" nmap <leader>f :CocList gfiles<CR>
" nmap <leader>g :Rg<CR>
nmap <leader>g :Leaderf rg<CR>
nmap <leader>m :Leaderf mru<CR>


nnoremap <leader>Fa :FlutterRun<cr>
nnoremap <leader>Fq :FlutterQuit<cr>
nnoremap <leader>Fr :FlutterHotReload<cr>
nnoremap <leader>FR :FlutterHotRestart<cr>
nnoremap <leader>Fd :FlutterVisualDebug<cr>
nnoremap <leader>Fo :sp __Flutter_Output__<cr>
nnoremap <leader>FO :tabe __Flutter_Output__<cr>

imap jk <esc>
