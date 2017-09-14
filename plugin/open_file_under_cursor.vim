" ----- Emulate 'gf' but recognize :line format -----
function! GotoFile(w)
    let curword = expand("<cfile>")
    if (strlen(curword) == 0)
        return
    endif
    let matchstart = match(curword, ':\d\+$')
    if matchstart > 0
        let pos = '+' . strpart(curword, matchstart+1)
        let fname = strpart(curword, 0, matchstart)
    else
        let pos = ""
        let fname = curword
    endif
 
    " check exists file.
    if filereadable(fname)
        let fullname = fname
    else
        " try find file with prefix by working directory
        for rootExt in ['', '.js', '.json', '.node', '/index.js']
            let fullname = getcwd() . '/' . fname . rootExt
            if filereadable(fullname)
                break
            endif
        endfor
        if ! filereadable(fullname)
            " the last try, using current directory based on file opened.
            " continue try for Node.js Module require algorithm
            for relativeExt in ['', '.js', '.json', '.node', '/index.js']
              let fullname = expand('%:h') . '/' . fname . relativeExt
              if filereadable(fullname)
                break
              endif
            endfor
        endif
        " after relative try, try node_modules
        if ! filereadable(fullname)
            " continue try for Node.js Module require algorithm
            for nodeModule in ['', '/..', '/../..']
                for moduleExt in ['', '.js', '.json', '.node', '/index.js', '/' . fname . '.js']
                    let fullname = getcwd() . nodeModule . '/node_modules/' . fname . moduleExt
                    if filereadable(fullname)
                        break
                    endif
                endfor
                if filereadable(fullname)
                    break
                endif
            endfor
        endif
    endif

   " Open new window if requested
    if a:w == "new"
        new
    endif
    " Use 'find' so path is searched like 'gf' would
    " execute 'find ' . pos . ' ' . fname
    execute 'find ' . pos . ' ' . fullname
endfunction

set isfname+=: " include colon in filenames

" Override vim commands 'gf', '^Wf', '^W^F'
nnoremap gf :call GotoFile("")<CR>
nnoremap <C-W>f :call GotoFile("new")<CR>
nnoremap <C-W><C-F> :call GotoFile("new")<CR>
