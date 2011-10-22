"=============Vim Config For EmergeW ======
"
"


if  has("unix")
    let g:OS#type=1
elseif has("win32") || has("win32unix")
    let g:OS#type=2
elseif has("mac")
    let g:OS#type=3
endif

if has("gui_running")
    let g:OS#gui=1
else
    let g:OS#gui=0
endif

if g:OS#type == 1
    source $VIMRUNTIME/vimrc_example.vim
    source $VIMRUNTIME/mswin.vim
    behave mswin
endif


"let vim work on an provide way
set nocompatible
"font and color
"set guifont=Droid\ Sans\ Mono\ 10
set guifont=Consolas\ 10
set lines=32 columns=136
"theme
colorscheme vividchalk


set encoding=utf-8
set termencoding=utf-8
set fileencoding=utf-8
set fileencodings=ucs-bom,utf-8,gb19030,big5,cp936,latin1
set langmenu=zh_CN.utf-8
set helplang=cn
set fileformat=unix
set fileformats=unix,dos,mac

filetype plugin on
filetype indent on
filetype on
syntax  on

set number
set guioptions-=T
"set guioptions-=r
set cursorline
set cmdheight=1
set nostartofline
set backspace=indent,eol,start
set listchars=tab:>~,trail:@
set iskeyword-=_
set showcmd
set ruler
set wrap
set whichwrap=b,s,<,>,[,]
set list
set laststatus=2
set statusline=%F%m%r%h%w\ [FORMAT=%{&ff}]\ [TYPE=%Y]\ [ASCII=\%03.3b]\ [HEX=\%02.2B]\ [POS=%04l,%04v][%02p%%]\ [LEN=%L]

set softtabstop=4
set expandtab
set shiftwidth=4
set tabstop=4
set smarttab

set linebreak
set autoindent
set smartindent
set ignorecase
set smartcase
set autoread
set showmatch
set nobackup
set history=50
set incsearch
set lbr

if &t_Co>2 || g:OS#gui
	syntax on
	set hlsearch
endif

source ~/.vim/emergew.vim
