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

" 画面の更新程度
let s:buffer_redraw_fps = 1000 / 10



"------------------------------------------------------------
" Objects
"------------------------------------------------------------

" 自機オブジェクト
" icon - ユーザを示す文字
" now_place - 前回のカーソル位置情報を保存 [bufnum, lnum, col, off]
let s:player_obj = {
            \ 'icon' : '@',
            \ 'now_place' : [],
            \ 'life' : 100,
            \ }


" 自機アイコンを描画
function s:player_obj.draw_icon(bufnum, lnum, col)
    execute 'buffer' a:bufnum
    execute 'normal! r '

    let save_cursor = getpos('.')

    call cursor(a:lnum, a:col)
    execute 'normal! r'.self.icon

    call setpos('.', save_cursor)
endfunction


" 自機の場所を更新しアイコンを再描画
function s:player_obj.update_place(pos)
    if type(a:pos) != type([])
        throw 'ROGUE-ERROR (type error)'
    endif

    " buffer番号は大抵0がくるのでここで変更
    let a:pos[0] = s:main_buf_num

    let self.now_place = a:pos

    " 自機を描画
    call s:change_buf_modifiable(a:pos[0], 1)
    call self.draw_icon(a:pos[0], a:pos[1], a:pos[3])
    call s:change_buf_modifiable(a:pos[0], 0)
endfunction


lockvar 1 s:player_obj


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



"------------------------------------------------------------
" Main Functions
"------------------------------------------------------------

" 初期化
function! s:initialize()
    let backup_sessionoptions = &sessionoptions
    set sessionoptions=blank,buffers,curdir,resize,help,tabpages,winsize    " optionsを含めないこと

    " 現在のセッションを保存
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

    " ステータス行分を確保し, 初期のマップデータを配置
    execute 'normal! ' . s:status_line_size . 'i '
    call append(s:status_line_size + 1, s:mapdata_lst[s:load_mapdata('rogue_map.txt')])

    " 空行を削除しカーソルを先頭へ
    g/^$/d
    call cursor(2, 2)   " マップもランダムに生成するなら開始位置も計算必要ありか
    let s:player_obj.update_place([s:main_buf_num, 2, 2, 0])
    call s:change_buf_modifiable(s:main_buf_num, 0)

    redraw!

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
        endif

        " 今のカーソル位置情報を保存し再描画
        call s:player_obj.update_place(copy(c_pos))

        redraw
        execute 'sleep ' . s:buffer_redraw_fps . 'm'
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
