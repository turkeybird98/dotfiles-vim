" File: flood#check_contents.vim
" Author: Shinya Ohyanagi <sohyanagi@gmail.com>
" WebPage:  http://github.com/heavenshell/vim-flood/
" Description: Vim plugin for Facebook FlowType.
" License: BSD, see LICENSE for more details.

let s:save_cpo = &cpo
set cpo&vim

function! s:run_callback(name)
  if flood#has_callback('check_contents', a:name)
    call g:flood_callbacks['check_contents'][a:name]()
  endif
endfunction

function! s:parse(errors)
  let outputs = []
  for e in a:errors
      let text = ''
      let line = has_key(e, 'operation') ? e['operation']['line'] : -1
      "let start = has_key(e, 'operation') ? e['operation']['start'] : -1
      let start = -1
      for message in e['message']
        let text = text . ' ' . message['descr']
        if line == -1
          let line = message['line']
        endif
        if start == -1
          let start = message['start']
        endif
      endfor
      let text = substitute(text, '^\s', '', 'g')

      let level = e['level'] ==# 'error' ? 'E' : 'W'
      call add(outputs, {
            \ 'filename': expand('%t'),
            \ 'lnum': line,
            \ 'col': start,
            \ 'vcol': 0,
            \ 'text': printf('[Flow] %s', text),
            \ 'type': level
            \})
  endfor
  return outputs
endfunction

" Callback function for `flow check-contents`.
" Create quickfix if error contains
function! s:check_callback(ch, msg, mode)
  try
    let responses = json_decode(a:msg)
    let outputs = s:parse(responses['errors'])
    if g:flood_enable_quickfix == 1 && responses['passed'] && len(getqflist()) == 0
      if len(outputs) == 0
        " No Errors. Clear quickfix then close window if exists.
        call setqflist([], 'r')
        cclose
        return
      endif
    endif

    " Create quickfix via setqflist().
    call setqflist(outputs, a:mode)
    if len(outputs) > 0 && g:flood_enable_quickfix == 1
      cwindow
    endif
  catch
    echomsg 'Flow server is not running.'
    call flood#log(v:exception)
    call flood#log(a:msg)
  finally
    call s:run_callback('check_contents')
  endtry
endfunction

" Execute `flow check-contents` job.
function! flood#check_contents#run(...) abort
  if exists('s:job') && job_status(s:job) != 'stop'
    call job_stop(s:job)
  endif
  call s:run_callback('check_contents')

  let bufnum = bufnr('%')
  let input = join(getbufline(bufnum, 1, '$'), "\n") . "\n"
  if g:flood_detect_flow_statememt == 1 && input !~ '@flow'
    call flood#log('`@flow` statement not found.')
    return
  endif

  let mode = a:0 > 0 ? a:1 : 'r'

  let file = expand('%:p')
  let cmd = printf('%s check-contents %s --json', flood#flowbin(), file)
  let s:job = job_start(cmd, {
        \ 'callback': {c, m -> s:check_callback(c, m, mode)},
        \ 'in_io': 'buffer',
        \ 'in_name': file
        \ })
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo

