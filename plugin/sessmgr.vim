" Manages sessions 
" vim: nowrap ts=4 sw=4 sts=4 ft=vim :
" Last Update: Wed 01 May 2002 08:47:03
if exists("g:loaded_sessmgr") 
	finish
endif

fun! SessGUI()
endfun
fun! SessNONGUI()
endfun

if exists("g:session_none") || argc()
	let g:session_none = 1
	finish
endif
let g:loaded_sessmgr=1
let g:sessmgr_version='1.0'
if !exists("g:session_none")
	let g:session_none = 0
endif

" get current directory for session-loading purposes
if exists("g:session_dir")
	" someone set our cwd, so please change to it:
	exe 'cd ' . g:session_dir
else	
	let g:session_dir = getcwd()
endif

if g:session_dir =~? 'desktop\|tmp\|temp'
	let g:session_none = 1
endif

if !exists("g:session_menu")
	let g:session_menu='&Misc.session'
endif

" exit without saving the session ....
:command Quit :let g:session_none=1|:qa!
" open a particular session
command! -nargs=? Session call SessOpen(<q-args>,0)

" define all the functions we need:
fun! SessNew()
	silent! call SessSave()
	let g:session_name = input("What do you want to call the session? ")
	call SessTitle()
	call SessAddMenu(g:session_name)
	silent! exe '1,'.bufnr('$').' bw!'
	if exists("*UserOnSessNew")
		call UserOnSessNew()
	endif
endfunc

func! SessTitle()
	set titlestring=%{g:session_name}:\ %F%m%r
endfunc

fun! SessRemoveInternal(delete)
	" remove the session from the file:
	let cpo=&cpo
	set cpo-=A
	set cpo-=a
	let savesearch = @/
	let line = line('.')
	if (! a:delete)
		silent! .,/^SESSIONINFO:\|\%$/- w! >> sessions.old
	endif
	exe line+1
	let endline = search('^SESSIONINFO:')
	if endline > 0
		let endline = endline - 1
	else
		let endline = line('$')
	endif
		
	silent! exe line. ',' endline . ' d'
	let @/ = savesearch
	let &cpo=cpo
endfunc

fun! SessSave()
	if g:session_none
		return
	endif
	
	let g:Sesscwd=substitute(getcwd(), '\', '/', 'g')
	exe 'cd ' g:session_dir
	let ssopt=&sessionoptions
	let pm=&patchmode
	let vi=&vi
	set sessionoptions=winsize,globals,buffers,localoptions,folds,slash,curdir
	" write out the current session information
	set patchmode=
	if has("gui_running")
		let g:Sesswinpos = 'winpos '.getwinposx().' '.getwinposy()
		let g:Sesswinsize = 'set lines='.&lines.' columns='.&columns
		if exists("g:colors_name")
			let g:SesscolorGUI = g:colors_name
		endif
	else
		if exists("g:colors_name")
			let g:Sesscolor = g:colors_name
		endif
	endif
	let g:Sessionaltbuf = bufname("#")
	let fname = tempname()
	exe 'mks! ' . fname
	sp sessions.vim
	silent! exe 'g /^SESSIONINFO:\s*'.g:session_name. '/	:call SessRemoveInternal(1)'
	$put='SESSIONINFO: '.g:session_name
	exe '$read '.fname
	call delete(fname)
	$put='VIMINFO:'
	let fname = tempname()
	set vi=!,'50,\"50,/50,:50,h,c
	exe 'wv! ' . fname
	exe '$read '.fname
	call delete(fname)
	w
	bw
	cd -
	let &patchmode=pm
	let &sessionoptions=ssopt
	let &vi=vi
endfunc
au VimLeave * nested :silent! call SessSave()

fun! SessSaveAs()
	" clone this session under a different name:
	let nm=input("What is the new session name? ")
	if nm != ''
		let this_sess = g:session_name
		let g:session_name=nm
		call SessSave()
		let g:session_name=this_sess
		call SessSave()
	endif
endfunc

fun! SessDontSave()
	" invert the menu
	let g:session_none = !g:session_none
	if (g:session_none)
		exe 'aun 600.4 '.g:session_menu.".Don't\\ Save"
		exe 'am 600.4 '.g:session_menu.".Do\\ Save :call SessDontSave()<cr>"
	else
		exe 'aun 600.4 '.g:session_menu.".Do\\ Save"
		exe 'am 600.4 '.g:session_menu.".Don't\\ Save :call SessDontSave()<cr>"
	endif
endfunc

fun! SessOpen(name,reload)
	if (a:reload == 0)
		call SessSave()
		" Put the current session as the 'previous'
		let g:Sessprev = g:session_name
	endif
	exe 'cd ' g:session_dir
	silent! exe '1,'.bufnr('$').' bw!'
	new
	silent! read sessions.vim
	" Need to find the session
	if search('^SESSIONINFO:\s*'.a:name.'\s*$', 'w')
		" fine, we found it:
		call SessOpenInternal()
		let g:session_name = a:name
		if exists("*UserOnSessOpen")
			call UserOnSessOpen()
		endif
	else
		let g:session_name = a:name
		if exists("*UserOnSessNew")
			call UserOnSessNew()
		endif
	endif
	call histdel('/', '^SESSIONINFO:\s*')
endfunc

fun! SessTrim(name)
	let sn = substitute(a:name, '^\s\+', '', '')
	let sn = substitute(sn, '\s\+$', '', '')
	return sn
endfunc

fun! SessRemove(name)
	if a:name != 'DEFAULT'
		let answer = input('Delete or archive? To delete, write "del": ')
		" first close this session

		let pm=&patchmode
		set patchmode=
		let sn = SessTrim(a:name)
		if sn == g:Sessprev
			call SessOpen('DEFAULT',0)
		else
			call SessOpen(g:Sessprev,0)
		endif
		let s = escape(sn, ' .\/')
		silent! e sessions.vim
		if search('^SESSIONINFO:\s*'.sn.'\s*$', 'w')
			call SessRemoveInternal(answer ==? 'del')
		endif
		silent! w!
		b#
		bw#
		exe 'aun '.g:session_menu.'.REMOVE.'.s
		exe 'aun '.g:session_menu.'.'.s
		let &patchmode=pm
	endif
endfunc

fun! SessAddMenu(sessname)
	let sn = SessTrim(a:sessname)
	let s = escape(sn, ' .\/')
	if a:sessname != 'DEFAULT'
		exe 'am 600.100 '.g:session_menu.'.REMOVE.' . s . ' :call SessRemove("' . sn . '")<cr>'
	endif
	exe 'am 600.200 '.g:session_menu. '.'. s . ' :call SessOpen("' . sn . '",0)<cr>'
endfunc

" When this function is called, the 'session' master file is open to a line
" starting with 'SESSIONINFO:'  We need to write the session information to a
" file, and the viminfo information to a file. 
fun! SessOpenInternal()
	let pm=&pm
	let swf=&swf
	set pm=
	set noswf
	let line = line('.') 
	let lastline = search('^SESSIONINFO:','W')
	exe line
	let viline = search('^VIMINFO:','W')
	" fix up the various line numbers...
	if lastline == 0
		let lastline = line('$') + 1
	endif
	" if there is a viminfo for this session, write it out:
	if viline > 0 && (viline < lastline)
		silent! exe (viline+1) . ',' . (lastline-1) . ' w! ++ff=unix sessvimi'
	endif
	" write out session file to reread:
	if viline == 0 || (viline > lastline)
		let viline = lastline
	endif
	silent! exe (line+1) . ',' . (viline-1) . ' w! ++ff=unix sesssess'

	" remove this session file
	bw!
	" read the new session stuff
	silent! exe 'rv! sessvimi'
	call delete('sessvimi')
	
	silent! exe 'so sesssess'
	call delete("sesssess")
	if has("gui_running")
		call SessGUI()
	else
		call SessNONGUI()
	endif

	call SessTitle()
	let &pm=pm
	let &swf=swf

	" remove singleton empty file
	if bufexists(1) && (bufname(1) == '')
		bw! 1
	endif
endfunc

fun! SessNONGUI()
	if exists("g:Sesscolor")
		exe 'colors '.g:Sesscolor
	endif
	if exists("g:Sesscwd")
		exe 'cd '.g:Sesscwd
	endif
endfunc

fun! SessGUI()
	if exists("g:Sesswinpos")
		exe g:Sesswinpos
	endif
	if exists("g:Sesswinsize")
		exe g:Sesswinsize
	endif
	if exists("g:SesscolorGUI")
		exe 'colors '.g:SesscolorGUI
	endif
	if exists("g:Sesscwd")
		exe 'cd '.g:Sesscwd
	endif
endfunc

func! SessOpenPrev()
	if !exists("g:Sessprev")
		let g:Sessprev='DEFAULT'
	endif
	call SessOpen(g:Sessprev,0)
endfunc

" initialize the session menu:
silent! exe 'aun ' . g:session_menu
exe 'am 600.1 '.g:session_menu. ".New :call SessNew()<cr>"
exe 'am 600.2 '.g:session_menu.".Save :silent! call SessSave()<cr>"
exe 'am 600.3 '.g:session_menu.".Save\\ As :call SessSaveAs()<cr>"
exe 'am 600.4 '.g:session_menu.".Don't\\ Save :call SessDontSave()<cr>"
exe 'am 600.5 '.g:session_menu.".Reload :call SessOpen(g:session_name,1)<cr>"
exe 'am 600.6 '.g:session_menu.".- :"
exe 'am 600.7 '.g:session_menu.".PREVIOUS :call SessOpenPrev()<cr>"
exe 'am 600.8 '.g:session_menu.".DEFAULT :call SessOpen('DEFAULT',1)<cr>"

" look for a 'sessions.vim'
let g:session_name = 'DEFAULT'
if filereadable('sessions.vim')
	" open the file, and read it:
	new
	silent read sessions.vim
	" have any sessions been saved?
	if search('^SESSIONINFO:', 'w') > 0
		" there are sessions, let's populate the menu:
		let ls=@/
		g /^SESSIONINFO:/ :call SessAddMenu(substitute(getline('.'), '^SESSIONINFO:', '', ''))
		let @/=ls
		call histdel(-1)
		" we are positioned at the last sessioninfo, which is the most recent
		let g:session_name = substitute(getline('.'), '^SESSIONINFO:\s\+','','')
		let g:session_name = substitute(g:session_name, '\s\+$', '', '')
		" Load this session
		call SessOpenInternal()
		if exists("*UserOnSessOpen")
			call UserOnSessOpen()
		endif
	else
		if exists("*UserOnSessNew")
			call UserOnSessNew()
		endif
	endif
endif

finish

" ---- Documentation follows:
This script is a plugin for the Vim 6 series of editors.  The purpose is to
allow one to easily use sessions.

To use it, simply drop this file in your $VIMRUNTIME path somewhere, in one of
the 'plugins' directories.  See ':help plugin' if you don't know what that is.

OVERVIEW:

	When I start working on something new, I put all my files in a special
	directory, so I can keep track of them.  I also start gvim from that
	directory.  My startup scripts all take this into account, so I can have
	'per-project' settings.

	Among the things that are 'per-project', are the vim sessions.  A session
	includes all the buffers being worked on, search history etc. private to
	that session, the window layout and positions, etc.  Vim already provides
	a method for saving the layout etc, via the 'mksession' command.  The
	problem is that it is not so convenient to use -- one must give a file
	name to save to, and remember to 'source' that file when restoring the
	session.

	My solution borrows a bit from my experience with CodeWright, and enhances
	it considerably.  Sessions are available at a click of a menu; the
	previous session worked on is likewise available (allowing you to switch
	between two sub-project quickly and easily). The session currently active
	when Vim quits, is restored when vim starts up again in that (project)
	directory.  All sessions are stored in one file, 'sessions.vim', in the
	project directory.

DETAILS:

	When this plugin runs, it scoops up any 'sessions.vim' file that exists in
	the current directory.  It then parses it to see what sessions are inside,
	and creates a menu of sessions to use.

	Setting 'g:session_none' to 1 will prevent sessions from loading, as will
	starting vim with a file name or names on the command-line.

	By default, the current dir is used to find the sessions.vim file;
	however, you can set 'g:session_dir' to override this behavior.

	By default, the menu is created under '&Misc.session.' you can change
	'g:session_menu' if you would like some other place.
	
	New commands:

		:Quit				- quits without saving the session
		:Session name		- opens the session called 'name'
	

	Special user function:

		If you define these, they will get called by the session manager:

		UserOnSessNew()		- called just after a new session is created
		UserOnSessOpen()	- called just after a session is opened

	These let you e.g. set windows a special way, or ensure that certain files
	are loaded, or whatever ...
