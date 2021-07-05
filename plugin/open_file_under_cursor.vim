" ----- Emulate 'gf' but recognize :line format -----
function! GetFullNameAsFile(basename) 
    let fileExtArr = ['', '.js', '.json', '.node', '.ts', '.tsx', '.vue', '.scss']
    for fileExt in fileExtArr
        let fullname =  a:basename . fileExt
        if filereadable(fullname)
            return fullname
        endif
    endfor
    return ''
endfunction
function! AppendIndexAsFile(basename)
    let fullname = GetFullNameAsFile(a:basename)
    if ! len(fullname) 
        let fullname = GetFullNameAsFile(a:basename . '/index')
    endif
    return fullname
endfunction
function! GetFullNameAsDirectory(basename)
    let packagename = a:basename . '/package.json'
    if filereadable(packagename)
        let lines = readfile(packagename)
        for field in ['"module"', '"main"'] 
            for line in lines
                if line =~ field
                    let basename = a:basename . '/' . substitute(line, field . ':\|[," ]', '', 'g')
                    let fullNameAppendIndex = AppendIndexAsFile(basename)
                    if len(fullNameAppendIndex)
                        return fullNameAppendIndex
                    endif
                endif
            endfor
        endfor
    endif
    return AppendIndexAsFile(a:basename)
endfunction
function! GetFullNameFromNodeMoudles(fname)
    let filePath = expand('%:p:h')
    let arr = split(a:fname, '/')
    let packageName = arr[0]
    if arr[0][0] == '@'
        packageName = arr[0] . '/' . arr[1]
    endif

    while len(filePath)
        let basename = filePath . '/node_modules/' . a:fname
        let fullNameAsDirectory = GetFullNameAsDirectory(basename)
        if len(fullNameAsDirectory)
            return fullNameAsDirectory
        endif
        " support package.json exports: {'./': './src/'}
        let packageRoot = filePath . '/node_modules/' . packageName
        if filereadable(packageRoot . '/package.json') && isdirectory(packageRoot . '/src')
            let basename = packageRoot . '/src' . substitute(a:fname, packageName, '', '')
            let fullNameAsDirectory = GetFullNameAsDirectory(basename)
            if len(fullNameAsDirectory)
                return fullNameAsDirectory
            endif
        endif
        if filePath == '/'
            break
        endif
        let filePath = fnamemodify(filePath, ':h')
    endwhile
    return ''
endfunction
function! GetFullNameFromBabelResolver(fname)
    " support babel plugin: ['moudle-resolver', {root: ['.', './src']}]
    " eslintConfig in package.json eslint-plugin-import node resolver: {moduleDirectory: ['./src']}
    let configFiles = ['.babelrc', 'babel.config.js', 'tsconfig.json', 'package.json']
    let roots = ['/', '/src/']
    let filePath = expand('%:p:h')
    while len(filePath)
        for config in configFiles
            let configFile =  filePath . '/' . config
            for root in roots
                let fullName = GetFullNameAsDirectory(filePath . root . a:fname)
                if filereadable(configFile) && filereadable(fullName)
                    return fullName
                endif
            endfor
        endfor
        if filePath == '/'
            break
        endif
        let filePath = fnamemodify(filePath, ':h')
    endwhile
    return ''
endfunction
function! GetFullNameFromAlias(fname)
    let configFiles = ['.eslintrc', '.eslintrc.js', 'webpack.config.js']
    let filePath = expand('%:p:h')
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
                            return GetFullNameAsDirectory(filePath . '/' . substitute(a:fname, aliasList[1], aliasList[2], ''))
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
        let fullname = GetFullNameAsDirectory(basename)
    else
        " try node_modules
        let fullname = GetFullNameFromNodeMoudles(fname)
        " try babel plugin moudle resolver
        if ! len(fullname)
            let fullname = GetFullNameFromBabelResolver(fname)
        endif
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
