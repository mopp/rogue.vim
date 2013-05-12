scriptencoding = utf-8

" 存在するなら読み込み済みなのでfinish
if exists("g:loaded_vimrogue") || 1 == &compatible
    finish
endif
let g:loaded_vimrogue = 1



"------------------------------------------------------------
" Variables
"------------------------------------------------------------

" For debug.
let s:DEBUG_FLAG = 1
lockvar s:DEBUG_FLAG

" buffer先頭に表示するステータスの行数
let s:status_line_size = 1
lockvar s:status_line_size

" 使用するbuffer名
let s:main_buf_name = '==ROGUE=='
lockvar s:main_buf_name

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()

" 使用するbuffer番号
let s:main_buf_num = -1

" ゲームのマップデータ listの入れ子 TODO:ランダムで生成, mapデータ用のディレクトリを決めて一括読み込み
let s:mapdata_lst = []

" 前回のカーソル位置情報を保存 [bufnum, lnum, col, off]
let s:prev_cursor_pos = []

" 画面の更新程度
let s:buffer_redraw_fps = 1000 / 60



"------------------------------------------------------------
" Util Functions
"------------------------------------------------------------

" for debug.
function! s:print_debug_msg(msg)
    if s:DEBUG_FLAG
        echomsg a:msg
    endif
endfunction


" 指定したファイル名のデータをマップデータリストに追加
" 読み込まれたリストの添字を返す
function! s:load_mapdata(file)
    if !filereadable(a:file)
        throw 'ROGUE-ERROR (cannot read mapdata file)'
        return
    endif

    call add(s:mapdata_lst, readfile(a:file))

    return len(s:mapdata_lst) - 1
endfunction


" 指定bufferのmodifiableを切り替える
function! s:change_buf_modifiable(buf_num, is_modif)
    " bufferが異なっていれば切り替え対象のバッファに移動
    if a:buf_num != bufnr('%')
        let saved_buf_num = bufnr('%')
        silent! 'buffer' a:buf_num
    endif

    " modifiable変更
    if a:is_modif == 0
        setlocal nomodifiable
    else
        setlocal modifiable
    endif

    if exists('saved_buf_num')
        silent! 'buffer' saved_buf_num
    endif
endfunction


" mappingを定義 呼び出すタイミングには注意
function! s:define_mappings()
    nnoremap <silent> <script> <Plug>call_finalize :call <SID>finalize()<CR>

    " TODO:あとでpluginへ持ってく
    nmap <buffer> q <Plug>call_finalize
endfunction



"------------------------------------------------------------
" Main Functions
"------------------------------------------------------------

" 初期化
function! s:initialize()
    " 現在のセッションを保存
    let backup_sessionoptions = &sessionoptions
    " optionsを含めないこと
    set sessionoptions=blank,buffers,curdir,folds,help,tabpages,winsize

    execute 'mksession!' s:stored_session_filename
    call writefile(['set bg='.&bg, 'colorscheme ' . g:colors_name], s:stored_session_filename . 'x.vim')

    let &sessionoptions = backup_sessionoptions
    unlet backup_sessionoptions

    " windowを作成
    execute 'silent! split' s:main_buf_name

    " buffer番号を保存
    let s:main_buf_num = bufnr('%')

    " 現在windowのみに
    only

    " 設定変更
    setlocal noswapfile lazyredraw
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8

    " mapping定義
    " call s:define_mappings()

    " ステータス行分を確保し, 初期のマップデータを配置
    execute 'normal! ' . s:status_line_size . 'i '
    call append(s:status_line_size + 1, s:mapdata_lst[s:load_mapdata('rogue_map.txt')])

    " 空行を削除しカーソルを先頭へ
    g/^$/d
    call cursor(2, 2)   " マップもランダムに生成するなら開始位置も計算必要ありか
    let s:prev_cursor_pos = [s:main_buf_num, 2, 2, 0]

    call s:change_buf_modifiable(s:main_buf_num, 0)

    call s:print_debug_msg('initialized !')
endfunction


" 終了処理
function! s:finalize()
    " 保存した設定を復元
    execute 'source' s:stored_session_filename

    call s:print_debug_msg('finalized !')
endfunction


" rogue主処理
function! s:rogue_main()
    redraw

    " 主処理
    while 1
        " 文字を取得出来るまで停止
        let in_char_code = getchar()

        " [bufnum, lnum, col, off]
        let c_pos = getpos('.')

        if in_char_code != 0
            let in_char = nr2char(in_char_code)

            if in_char ==? 'q'
                break
            endif

            echo 'Now is ' . in_char
        endif

        " 今のカーソル位置情報を保存
        let s:prev_cursor_pos = copy(c_pos)

        redraw
        " execute 'sleep ' . s:buffer_redraw_fps . 'm'
    endwhile
endfunction



"------------------------------------------------------------
" Commands
"------------------------------------------------------------

" TODO: ユーティリティ系でもいれよう


call s:initialize()
" TODO タイトル画面的なのを挟んで、mappingでスタートトリガーを打つ
call s:rogue_main()
call s:finalize()
