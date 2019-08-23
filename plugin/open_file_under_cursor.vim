" ----- Emulate 'gf' but recognize :line format -----
function! GetFullNameAsFile(basename) 
    let fileExtArr = ['', '.js', '.json', '.node', '.ts', '.tsx', '.scss', '.vue']
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
    let filePath = expand('%:h')
    while len(filePath)
        let basename = filePath . '/node_modules/' . a:fname
        " load as file
        let fullNameAsFile = GetFullNameAsFile(basename)
        if len(fullNameAsFile)
            return fullNameAsFile
        endif
        let fullNameAsDirectory = GetFullNameAsDirectory(basename)
        if len(fullNameAsDirectory)
            return fullNameAsDirectory
        endif
        if filePath == '/'
            break
        endif
        let filePath = fnamemodify(filePath, ':h')
    endwhile
    return ''
endfunction
function! GetFullNameFromAlias(fname)
    let configFiles = ['.eslintrc', '.eslintrc.js', 'webpack.config.js']
    let filePath = expand('%:h')
    while len(filePath)
        for config in configFiles
            let configFile =  filePath . '/' . config
            if filereadable(configFile)
                let aliasBlock = 0
                for configLine in readfile(configFile)
                    if configLine =~ 'alias'
                        let aliasBlock = 1
                        continue
                    endif
                    if aliasBlock
                        if configLine =~ '},\?$'
                            break
                        endif
                        let aliasList = matchlist(configLine, "^\\s\*['\"]\\?\\([^'\"]\\+\\)['\"]\\?[^'\"]\\+['\"]\\([^'\"]\\+\\)")
                        if a:fname =~ '^' . aliasList[1]
                            return filePath . '/' . substitute(a:fname, aliasList[1], aliasList[2], '')
                        endif
                    endif
                endfor
            endif
        endfor
        if filePath == '/'
            break
        endif
        let filePath = fnamemodify(filePath, ':h')
    endwhile
    return ''
endfunction
function! GotoFile(w)
    " replace ~ for scss import
    let curword = substitute(matchstr(getline('.'), "['\"][^'\"]\*['\"]"), "['\"~]", '', 'g')
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
        " try eslint or webpack alias
        if ! len(fullname)
            let fullname = GetFullNameFromAlias(fname)
        endif
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
