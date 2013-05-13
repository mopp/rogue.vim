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

" ゲームのマップデータ listの入れ子 TODO:ランダムで生成, mapデータ用のディレクトリを決めて一括読み込み
let s:mapdata_lst = []

" 画面の更新程度
let s:buffer_redraw_fps = 1000 / 10



"------------------------------------------------------------
" Objects
"------------------------------------------------------------

" 自機オブジェクト
" icon - ユーザを示す文字
" now_place - 前回のカーソル位置情報を保存 {lnum, col, map_obj}
let s:player_obj = {
            \ 'icon' : '@',
            \ 'bufnum' : -1,
            \ 'now_place' : {
            \   'lnum' : -1,
            \   'col' : -1,
            \   'map_obj' : ' ',
            \ },
            \ 'life' : 100,
            \ }


" 自機を初期化
function! s:player_obj.init(lnum, col)
    call s:player_obj.draw_icon(a:lnum, a:col)
endfunction


" 指定座標に何があるのかチェック
function! s:player_obj.check_target(lnum, col)

endfunction


" 指定座標に自機アイコンを描画, 座標の更新も行う
function! s:player_obj.draw_icon(lnum, col)
    " 別バッファの場合
    if self.bufnum != bufnr('%')
        execute 'buffer' self.bufnum
    endif

    call s:change_buf_modifiable(self.bufnum, 1)

    let place = self.now_place

    " 移動するので現在座標にあったマップ上のオブジェクトを復元
    call cursor(place.lnum, place.col)
    execute 'normal! r'.place.map_obj

    " 通過後に復元するため, 移動先のオブジェクトを保存
    let place.map_obj = s:get_position_char(a:lnum, a:col)

    " 自機描画
    call cursor(a:lnum, a:col)
    execute 'normal! r'.self.icon

    " 自機座標更新
    let place.lnum = a:lnum
    let place.col = a:col

    call s:change_buf_modifiable(self.bufnum, 0)
endfunction


" 自機を移動
function! s:player_obj.move(cmd)
    " call s:print_debug_msg('called player move '.a:cmd)

    let n_lnum = self.now_place.lnum
    let n_col = self.now_place.col

    " TODO : 移動可能か判定

    if a:cmd ==# 'h'
        let n_col = n_col - 1
    elseif a:cmd ==# 'j'
        let n_lnum = n_lnum + 1
    elseif a:cmd ==# 'k'
        let n_lnum = n_lnum - 1
    elseif a:cmd ==# 'l'
        let n_col = n_col + 1
    endif

    " 自機を描画
    call s:player_obj.draw_icon(n_lnum, n_col)
endfunction



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
function! s:change_buf_modifiable(bufnum, is_modif)
    " bufferが異なっていれば切り替え対象のバッファに移動
    if a:bufnum != bufnr('%')
        let saved_bufnum = bufnr('%')
        silent! 'buffer' a:bufnum
    endif

    " modifiable変更
    if a:is_modif == 0
        setlocal nomodifiable
    else
        setlocal modifiable
    endif

    if exists('saved_bufnum')
        silent! 'buffer' saved_bufnum
    endif
endfunction


" 指定座標から一文字取得
function! s:get_position_char(lnum, col)
    return matchstr(getline(a:lnum), '.', a:col - 1)
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

    " 新規に全画面windowを作成
    execute 'silent! split' s:main_buf_name
    only

    " buffer番号を保存
    let s:player_obj.bufnum = bufnr('%')

    " 現在windowのみに

    " 設定変更
    setlocal noswapfile lazyredraw
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8
    setlocal nocursorline nofoldenable

    " ステータス行分を確保し, 初期のマップデータを配置
    execute 'normal! ' . s:status_line_size . 'i '
    call append(s:status_line_size + 1, s:mapdata_lst[s:load_mapdata('rogue_map.txt')])

    " 空行を削除
    g/^$/d

    " 自機オブジェクト初期化
    call s:player_obj.init(3, 3)   " マップもランダムに生成するなら開始位置も計算必要ありか

    call s:change_buf_modifiable(s:player_obj.bufnum, 0)

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

        if in_char_code != 0
            let in_char = nr2char(in_char_code)

            if in_char ==? 'q'
                " 終了
                break
            elseif (in_char ==# 'h') || (in_char ==# 'j') || (in_char ==# 'k') || (in_char ==# 'l')
                " 移動
                call s:player_obj.move(in_char)
            endif
        endif

        " 再描画
        redraw
    endwhile
endfunction



"------------------------------------------------------------
" Commands
"------------------------------------------------------------

" TODO タイトル画面的なのを挟んで、mappingでスタートトリガーを打つ
" command! -nargs=0 RogueStart call s:initialize() | call s:rogue_main() | call s:finalize()

call s:initialize()
call s:rogue_main()
call s:finalize()
