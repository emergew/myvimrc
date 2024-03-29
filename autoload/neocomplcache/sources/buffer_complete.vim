"=============================================================================
" FILE: buffer_complete.vim
" AUTHOR:  Shougo Matsushita <Shougo.Matsu@gmail.com>
" Last Modified: 14 Oct 2011.
" License: MIT license  {{{
"     Permission is hereby granted, free of charge, to any person obtaining
"     a copy of this software and associated documentation files (the
"     "Software"), to deal in the Software without restriction, including
"     without limitation the rights to use, copy, modify, merge, publish,
"     distribute, sublicense, and/or sell copies of the Software, and to
"     permit persons to whom the Software is furnished to do so, subject to
"     the following conditions:
"
"     The above copyright notice and this permission notice shall be included
"     in all copies or substantial portions of the Software.
"
"     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"     OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"     MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"     IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"     CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"     TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"     SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

" Important variables.
if !exists('s:buffer_sources')
  let s:buffer_sources = {}
endif

let s:source = {
      \ 'name' : 'buffer_complete',
      \ 'kind' : 'complfunc',
      \}

function! s:source.initialize()"{{{
  augroup neocomplcache"{{{
    " Caching events
    autocmd InsertEnter * call s:check_source()
    autocmd CursorHold * call s:check_deleted_buffer()
    autocmd InsertLeave *
          \ call neocomplcache#sources#buffer_complete#caching_current_cache_line()
    autocmd VimLeavePre * call s:save_all_cache()
  augroup END"}}}

  " Set rank.
  call neocomplcache#set_dictionary_helper(g:neocomplcache_plugin_rank,
        \ 'buffer_complete', 4)

  " Set completion length.
  call neocomplcache#set_completion_length('buffer_complete', 2)

  " Create cache directory.
  if !isdirectory(g:neocomplcache_temporary_dir . '/buffer_cache')
    call mkdir(g:neocomplcache_temporary_dir . '/buffer_cache', 'p')
  endif

  " Initialize script variables."{{{
  let s:buffer_sources = {}
  let s:filetype_frequencies = {}
  let s:cache_line_count = 70
  let s:rank_cache_count = 1
  let s:disable_caching_list = {}
  let s:completion_length = g:neocomplcache_auto_completion_start_length
  "}}}

  " Add commands."{{{
  command! -nargs=? -complete=buffer NeoComplCacheCachingBuffer call s:caching_buffer(<q-args>)
  command! -nargs=? -complete=buffer NeoComplCachePrintSource call s:print_source(<q-args>)
  command! -nargs=? -complete=buffer NeoComplCacheOutputKeyword call s:output_keyword(<q-args>)
  command! -nargs=? -complete=buffer NeoComplCacheSaveCache call s:save_all_cache()
  command! -nargs=? -complete=buffer NeoComplCacheDisableCaching call s:disable_caching(<q-args>)
  command! -nargs=? -complete=buffer NeoComplCacheEnableCaching call s:enable_caching(<q-args>)
  "}}}
endfunction
"}}}

function! s:source.finalize()"{{{
  delcommand NeoComplCacheCachingBuffer
  delcommand NeoComplCachePrintSource
  delcommand NeoComplCacheOutputKeyword
  delcommand NeoComplCacheSaveCache
  delcommand NeoComplCacheDisableCaching
  delcommand NeoComplCacheEnableCaching

  call s:save_all_cache()

  let s:buffer_sources = {}
endfunction"}}}

function! s:source.get_keyword_pos(cur_text)"{{{
  let [cur_keyword_pos, cur_keyword_str] = neocomplcache#match_word(a:cur_text)

  return cur_keyword_pos
endfunction"}}}

function! s:source.get_complete_words(cur_keyword_pos, cur_keyword_str)"{{{
  let keyword_list = []
  for src in s:get_sources_list()
    let keyword_cache = neocomplcache#dictionary_filter(
          \ s:buffer_sources[src].keyword_cache,
          \ a:cur_keyword_str, s:completion_length)
    if src == bufnr('%')
      call s:calc_frequency()
    endif

    let keyword_list += keyword_cache
  endfor

  return keyword_list
endfunction"}}}

function! neocomplcache#sources#buffer_complete#define()"{{{
  return s:source
endfunction"}}}

function! neocomplcache#sources#buffer_complete#get_frequencies()"{{{
  let filetype = neocomplcache#get_context_filetype()
  if !has_key(s:filetype_frequencies, filetype)
    return {}
  endif

  return s:filetype_frequencies[filetype]
endfunction"}}}

function! neocomplcache#sources#buffer_complete#caching_current_cache_line()"{{{
  " Current line caching.
  return s:caching_current_buffer(line('.')-1, line('.')+1)
endfunction"}}}
function! s:caching_current_buffer(start, end)"{{{
  " Current line caching.

  if !s:exists_current_source() || has_key(s:disable_caching_list, bufnr('%'))
    return
  endif

  let source = s:buffer_sources[bufnr('%')]
  let filename = fnamemodify(source.name, ':t')
  let menu = '[B] ' . neocomplcache#util#strwidthpart(
        \ filename, g:neocomplcache_max_menu_width)
  let keyword_pattern = source.keyword_pattern
  let keyword_pattern2 = '^\%('.keyword_pattern.'\m\)'
  let keywords = source.keyword_cache
  let frequencies = source.frequencies

  let line = join(getline(a:start, a:end))
  let match = match(line, keyword_pattern)
  while match >= 0"{{{
    let match_str = matchstr(line, keyword_pattern2, match)

    " Ignore too short keyword.
    if len(match_str) >= g:neocomplcache_min_keyword_length"{{{
      " Check dup.
      let key = tolower(match_str[: s:completion_length-1])
      if !has_key(keywords, key)
        let keywords[key] = {}
      endif
      if !has_key(keywords[key], match_str)
        " Append list.
        let keywords[key][match_str] =
              \ { 'word' : match_str, 'menu' : menu, 'rank' : 0 }
      endif
      if !has_key(frequencies, match_str)
        let frequencies[match_str] = 1
      endif

      let frequencies[match_str] += 1
    endif"}}}

    " Next match.
    let match = match(line, keyword_pattern, match + len(match_str))
  endwhile"}}}
endfunction"}}}

function! s:calc_frequency()"{{{
  if !s:exists_current_source()
    return
  endif

  let filetype = neocomplcache#get_context_filetype()
  if !has_key(s:filetype_frequencies, filetype)
    let s:filetype_frequencies[filetype] = {}
  endif

  if s:rank_cache_count >= 0
    let s:rank_cache_count -= 1
    return
  endif

  let source = s:buffer_sources[bufnr('%')]

  let list_len = len(source.frequencies)

  if list_len > g:neocomplcache_max_list * 5
    let calc_cnt = 15
  elseif list_len > g:neocomplcache_max_list * 3
    let calc_cnt = 13
  elseif list_len > g:neocomplcache_max_list
    let calc_cnt = 10
  elseif list_len > g:neocomplcache_max_list / 2
    let calc_cnt = 8
  elseif list_len > g:neocomplcache_max_list / 3
    let calc_cnt = 5
  elseif list_len > g:neocomplcache_max_list / 4
    let calc_cnt = 4
  else
    let calc_cnt = 3
  endif

  " Reset count.
  let s:rank_cache_count = neocomplcache#rand(calc_cnt)

  let prev_frequencies = source.prev_frequencies
  let filetype_frequencies = s:filetype_frequencies[filetype]
  for [word, rank] in items(source.frequencies)
    " Set rank.
    if !has_key(filetype_frequencies, word)
      let filetype_frequencies[word] = 0
    endif

    " Reset rank.
    if has_key(prev_frequencies, word)
      let filetype_frequencies[word] -= prev_frequencies[word]
    endif

    let filetype_frequencies[word] += rank
    let prev_frequencies[word] = rank
  endfor
endfunction"}}}

function! s:get_sources_list()"{{{
  let sources_list = []

  let filetypes_dict = {}
  for filetype in neocomplcache#get_source_filetypes(
        \ neocomplcache#get_context_filetype())
    let filetypes_dict[filetype] = 1
  endfor

  for key in keys(s:buffer_sources)
    if has_key(filetypes_dict, s:buffer_sources[key].filetype)
          \ || bufnr('%') == key
          \ || (bufname('%') ==# '[Command Line]' && bufnr('#') == key)
      call add(sources_list, key)
    endif
  endfor

  return sources_list
endfunction"}}}

function! s:initialize_source(srcname)"{{{
  let path = fnamemodify(bufname(a:srcname), ':p')
  let filename = fnamemodify(path, ':t')
  if filename == ''
    let filename = '[No Name]'
    let path .= '/[No Name]'
  endif

  let ft = getbufvar(a:srcname, '&filetype')
  if ft == ''
    let ft = 'nothing'
  endif

  let buflines = getbufline(a:srcname, 1, '$')
  let keyword_pattern = neocomplcache#get_keyword_pattern(ft)

  let s:buffer_sources[a:srcname] = {
        \ 'keyword_cache' : {}, 'frequencies' : {}, 'prev_frequencies' : {},
        \ 'name' : filename, 'filetype' : ft, 'keyword_pattern' : keyword_pattern,
        \ 'end_line' : len(buflines),
        \ 'check_sum' : len(join(buflines[:4], '\n')),
        \ 'path' : path, 'loaded_cache' : 0,
        \ 'cache_name' : neocomplcache#cache#encode_name('buffer_cache', path),
        \}
endfunction"}}}

function! s:word_caching(srcname)"{{{
  " Initialize source.
  call s:initialize_source(a:srcname)

  let source = s:buffer_sources[a:srcname]
  let srcname = fnamemodify(source.name, ':p')

  if neocomplcache#cache#check_old_cache('buffer_cache', srcname)
    if source.name ==# '[Command Line]'
          \ || getbufvar(a:srcname, '&buftype') =~ 'nofile'
      " Ignore caching.
      return
    endif

    let source.cache_name =
          \ neocomplcache#cache#async_load_from_file(
          \     'buffer_cache', source.path, source.keyword_pattern, 'B')
  endif
endfunction"}}}

function! s:check_changed_buffer(bufnumber)"{{{
  let source = s:buffer_sources[a:bufnumber]

  if getbufvar(a:bufnumber, '&buftype') =~ 'nofile'
    " Check buffer changed.
    let check_sum = len(join(getbufline(a:bufnumber, 1, 5), '\n'))
    if check_sum != source.check_sum
      " Recaching.
      return 1
    endif
  endif

  let ft = getbufvar(a:bufnumber, '&filetype')
  if ft == ''
    let ft = 'nothing'
  endif

  let filename = fnamemodify(bufname(a:bufnumber), ':t')
  if filename == ''
    let filename = '[No Name]'
  endif

  return s:buffer_sources[a:bufnumber].name != filename
        \ || s:buffer_sources[a:bufnumber].filetype != ft
endfunction"}}}

function! s:check_source()"{{{
  let bufnumber = bufnr('%')

  " Check new buffer.
  let bufname = fnamemodify(bufname(bufnumber), ':p')
  if (!has_key(s:buffer_sources, bufnumber) || s:check_changed_buffer(bufnumber))
        \ && !has_key(s:disable_caching_list, bufnumber)
        \ && !neocomplcache#is_locked(bufnumber)
        \ && !getwinvar(bufwinnr(bufnumber), '&previewwindow')
        \ && getfsize(bufname) < g:neocomplcache_caching_limit_file_size

    " Caching.
    call s:word_caching(bufnumber)
  endif

  if has_key(s:buffer_sources, bufnumber)
        \ && !s:buffer_sources[bufnumber].loaded_cache
    let source = s:buffer_sources[bufnumber]

    if filereadable(source.cache_name)
      " Caching from cache.
      call neocomplcache#cache#list2index(
            \ neocomplcache#cache#load_from_cache('buffer_cache', source.path),
            \ source.keyword_cache,
            \ s:completion_length)

      let source.loaded_cache = 1
    endif
  endif
endfunction"}}}
function! s:check_deleted_buffer()"{{{
  " Check deleted buffer.
  for key in keys(s:buffer_sources)
    if !bufloaded(str2nr(key))
      " Save cache.
      call s:save_cache(key)

      " Remove item.
      call remove(s:buffer_sources, key)
    endif
  endfor
endfunction"}}}

function! s:exists_current_source()"{{{
  return has_key(s:buffer_sources, bufnr('%'))
endfunction"}}}

function! s:save_cache(srcname)"{{{
  if s:buffer_sources[a:srcname].end_line < 500
    return
  endif

  if getbufvar(a:srcname, '&buftype') =~ 'nofile'
    return
  endif

  let srcname = fnamemodify(bufname(str2nr(a:srcname)), ':p')
  if !filereadable(srcname) ||
        \ (g:neocomplcache_disable_caching_file_path_pattern != ''
        \   && srcname =~ g:neocomplcache_disable_caching_file_path_pattern)
    return
  endif

  let cache_name = neocomplcache#cache#encode_name('buffer_cache', srcname)

  if filereadable(cache_name) &&
        \ (g:neocomplcache_disable_caching_file_path_pattern != ''
        \   && srcname =~ g:neocomplcache_disable_caching_file_path_pattern)
    " Delete cache file.
    call delete(cache_name)
    return
  endif

  if getftime(cache_name) >= getftime(srcname)
    return
  endif

  " Output buffer.
  call neocomplcache#cache#save_cache('buffer_cache', srcname, neocomplcache#unpack_dictionary(s:buffer_sources[a:srcname].keyword_cache))
endfunction "}}}
function! s:save_all_cache()"{{{
  try
    for key in keys(s:buffer_sources)
      call s:save_cache(key)
    endfor
  catch
    call neocomplcache#print_error('Error occured while saving cache!')
    let error_file = g:neocomplcache_temporary_dir . strftime('/error-%Y-%m-%d.log')
    call writefile([v:exception . ' ' . v:throwpoint], error_file)
    call neocomplcache#print_error('Please check error file: ' . error_file)
  endtry
endfunction"}}}

" Command functions."{{{
function! s:caching_buffer(name)"{{{
  if a:name == ''
    let number = bufnr('%')
  else
    let number = bufnr(a:name)

    if number < 0
      call neocomplcache#print_error('Invalid buffer name.')
      return
    endif
  endif

  " Word recaching.
  call s:word_caching(number)
  call s:caching_current_buffer(1, line('$'))
endfunction"}}}
function! s:print_source(name)"{{{
  if a:name == ''
    let number = bufnr('%')
  else
    let number = bufnr(a:name)

    if number < 0
      call neocomplcache#print_error('Invalid buffer name.')
      return
    endif
  endif

  if !has_key(s:buffer_sources, number)
    return
  endif

  silent put=printf('Print neocomplcache %d source.', number)
  for key in keys(s:buffer_sources[number])
    silent put =printf('%s => %s', key, string(s:buffer_sources[number][key]))
  endfor
endfunction"}}}
function! s:output_keyword(name)"{{{
  if a:name == ''
    let number = bufnr('%')
  else
    let number = bufnr(a:name)

    if number < 0
      call neocomplcache#print_error('Invalid buffer name.')
      return
    endif
  endif

  if !has_key(s:buffer_sources, number)
    return
  endif

  " Output buffer.
  for keyword in neocomplcache#unpack_dictionary(s:buffer_sources[number].keyword_cache)
    silent put=string(keyword)
  endfor
endfunction "}}}
function! s:disable_caching(name)"{{{
  if a:name == ''
    let number = bufnr('%')
  else
    let number = bufnr(a:name)

    if number < 0
      call neocomplcache#print_error('Invalid buffer name.')
      return
    endif
  endif

  let s:disable_caching_list[number] = 1

  if has_key(s:buffer_sources, number)
    " Delete source.
    call remove(s:buffer_sources, number)
  endif
endfunction"}}}
function! s:enable_caching(name)"{{{
  if a:name == ''
    let number = bufnr('%')
  else
    let number = bufnr(a:name)

    if number < 0
      call neocomplcache#print_error('Invalid buffer name.')
      return
    endif
  endif

  if has_key(s:disable_caching_list, number)
    call remove(s:disable_caching_list, number)
  endif
endfunction"}}}
"}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: foldmethod=marker
