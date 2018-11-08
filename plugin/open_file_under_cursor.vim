" ----- Emulate 'gf' but recognize :line format -----
function! GetFullNameAsFile(basename) 
    let fileExtArr = ['', '.js', '.json', '.node', '.ts', '.tsx', '.scss']
    for fileExt in fileExtArr
        let fullname =  a:basename . fileExt
        if filereadable(fullname)
            return fullname
        endif
    endfor
    return ''
endfunction
function! AppendIndexAsFile(basename)
    return GetFullNameAsFile(a:basename . '/index')
endfunction
function! GetFullNameAsDirectory(basename)
    let packagename = a:basename . '/package.json'
    if filereadable(packagename)
        for line in readfile(packagename)
            if line =~ '"main"'
                let basename = a:basename . '/' . substitute(line, '"main":\|[," ]', '', 'g')
                let fullNameAsFile = GetFullNameAsFile(basename)
                if len(fullNameAsFile)
                    return fullNameAsFile
                endif
                let fullNameAppendIndex = AppendIndexAsFile(basename)
                if len(fullNameAppendIndex)
                    return fullNameAppendIndex
                endif
            endif
        endfor
    endif
    return AppendIndexAsFile(a:basename)
endfunction
function! GetFullNameFromNodeMoudles(fname)
    for nodeModule in ['', '/..', '/../..']
        let basename = getcwd() . nodeModule . '/node_modules/' . a:fname
        " load as file
        let fullNameAsFile = GetFullNameAsFile(basename)
        if len(fullNameAsFile)
            return fullNameAsFile
        endif
        let fullNameAsDirectory = GetFullNameAsDirectory(basename)
        if len(fullNameAsDirectory)
            return fullNameAsDirectory
        endif
    endfor
endfunction
function! GotoFile(w)
    " replace ~ for scss import
    let curword = substitute(matchstr(getline('.'), "['\"][^'\"]\*['\"]"), "['\"~]", '', 'g')
    echo curword
    if (len(curword) == 0)
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
 
    " Node.js Module require algorithm
    if (fname =~ '^[./]')
        " start width . or /, relative check
        " using current directory based on file opened.
        let basename = expand('%:h') . '/' . fname
        let fullname = GetFullNameAsFile(basename)
        if ! len(fullname)
            let fullname = GetFullNameAsDirectory(basename)
        endif
    else
        " try node_modules
        let fullname = GetFullNameFromNodeMoudles(fname)
    endif

   " Open new window if requested
    if a:w != ""
        execute a:w
    endif
    " Use 'find' so path is searched like 'gf' would
    " execute 'find ' . pos . ' ' . fname
    execute 'find ' . pos . ' ' . fullname
endfunction

set isfname+=: " include colon in filenames

" Override vim commands 'gf', '^Wf', '^W^F'
nnoremap gf :call GotoFile("")<CR>
nnoremap <leader>fv :call GotoFile("vne")<CR>
nnoremap <leader>fs :call GotoFile("new")<CR>
" nnoremap <C-W>f :call GotoFile("vne")<CR>
" nnoremap <C-W><C-F> :call GotoFile("new")<CR>
