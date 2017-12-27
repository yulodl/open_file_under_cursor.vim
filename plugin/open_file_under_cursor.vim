" ----- Emulate 'gf' but recognize :line format -----
function! GotoFile(w)
    let curword = substitute(matchstr(getline('.'), "['\"][^'\"]\*['\"]"), "['\"]", '', 'g')
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
        let extArr = ['', '.js', '.json', '.node', '/index.js', '/index.json', '/index.node']
        " try find file with prefix by working directory
        for rootExt in extArr
            let fullname = getcwd() . '/' . fname . rootExt
            if filereadable(fullname)
                break
            endif
        endfor
        if ! filereadable(fullname)
            " the last try, using current directory based on file opened.
            " continue try for Node.js Module require algorithm
            for relativeExt in extArr
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
                let basename = getcwd() . nodeModule . '/node_modules/' . fname
                " load as file
                for moduleExt in extArr
                    let fullname = basename . moduleExt
                    if filereadable(fullname)
                        break
                    endif
                endfor
                " load as directory: find package.json 'main' field
                if ! filereadable(fullname)
                    let packagename = basename . '/package.json'
                    if filereadable(packagename)
                        for line in readfile(packagename)
                            if line =~ '"main"'
                                let fullname = basename . '/' . substitute(line, '"main":\|[," ]', '', 'g')
                                break
                            endif
                        endfor
                    endif
                endif
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
