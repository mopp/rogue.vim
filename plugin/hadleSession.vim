let s:stored_session_filename = tempname()

" 初期化
function! s:initialize()
    let backup_sessionoptions = &sessionoptions
    set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize

    " 現在のセッションを保存
    execute 'mksession!' s:stored_session_filename
    call writefile(['set bg='.&bg, 'colorscheme ' . g:colors_name], s:stored_session_filename . 'x.vim')

    let &sessionoptions = backup_sessionoptions
    unlet backup_sessionoptions

    " windowを作成
    execute 'silent! split moppbuf'

    " buffer番号を保存
    let s:main_buf_num = bufnr('%')

    " 現在windowのみに
    only

    " 設定変更
    setlocal noswapfile lazyredraw
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8

    call append(0, ['hoge', 'fuga', 'piyo'])
endfunction


" 終了処理
function! s:finalize()
    " 保存した設定を復元
    execute 'source' s:stored_session_filename
endfunction

" rogue主処理
function! s:main()
    redraw

    " 主処理
    while 1
        " 文字を取得出来るまで停止
        let in_char_code = getchar()

        if in_char_code != 0
            let in_char = nr2char(in_char_code)

            if in_char ==? 'q'
                break
            endif

            echo 'get is ' . in_char
        endif

        redraw
    endwhile
endfunction

call s:initialize()
call s:main()
call s:finalize()
