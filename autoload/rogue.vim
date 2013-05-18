scriptencoding = utf-8


" 存在するなら読み込み済みなのでfinish
if exists("g:loaded_vimrogue") || 1 == &compatible
    finish
endif
let g:loaded_vimrogue = 1



"------------------------------------------------------------
" Global Variables
"------------------------------------------------------------

" マップデータの保存ディレクトリ
let g:rogue_map_data_directly = substitute(expand('<sfile>:p:h'), '/autoload', '/map', 'g')



"------------------------------------------------------------
" File Local Variables
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

" 使用するbuffer番号
let s:main_buf_num = 0

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()

" 自機オブジェクト
let s:player_obj = {}

" マップについてのデータを持つオブジェクト TODO:階層的にする
let s:map_obj = {}



"------------------------------------------------------------
" Functions
"------------------------------------------------------------

" for debug.
function! s:print_debug_msg(msg)
    if s:DEBUG_FLAG
        echomsg string(a:msg)
    endif
endfunction


" 指定したファイル名からデータ読み込み
function! s:load_map_data_file(file)
    let filepath = g:rogue_map_data_directly . '/' . a:file

    if !filereadable(filepath)
        throw 'ROGUE-ERROR (cannot read mapdata file)'
        return
    endif

    return readfile(filepath)
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


" 自機を移動
function! s:move_player(map, player, cmd)
    " ここで直接書き換えると、オブジェクトの復元が出来ないため
    " 現在(移動前)の座標を別変数へ
    let place = a:player.now_place
    let n_lnum = place.lnum
    let n_col = place.col

    if 'h' ==# a:cmd
        let n_col -= 1
    elseif 'j' ==# a:cmd
        let n_lnum += 1
    elseif 'k' ==# a:cmd
        let n_lnum -= 1
    elseif 'l' ==# a:cmd
        let n_col += 1
    endif

    " 移動したい座標のオブジェクト取得
    let t_obj = a:map.get_obj(n_lnum, n_col)
    call s:print_debug_msg(t_obj)

    " オブジェクトの属性ビット取得
    let attr_bit = t_obj.obj_info.ATTR

    " ビットマスクで属性を判別
    if 0 != and(attr_bit, objects#get_attr_bit('THROUGH'))
        " 移動
        call s:change_buf_modifiable(s:main_buf_num, 1)

        " 移動するので現在座標にあったマップ上のオブジェクトを復元
        call cursor(place.lnum, place.col)
        execute 'normal! r'.place.map_obj

        " 通過後に復元するため, 移動先のオブジェクトを保存
        let place.map_obj = utils#get_position_char(n_lnum, n_col)

        " 自機描画
        call cursor(n_lnum, n_col)
        execute 'normal! r'.a:player.obj_info.ICON

        " 自機座標更新
        let place.lnum = n_lnum
        let place.col = n_col

        call s:change_buf_modifiable(s:main_buf_num, 0)
    elseif 0 != and(attr_bit, objects#get_attr_bit('ENEMY'))
        " 攻撃

    endif
endfunction



"------------------------------------------------------------
" Global Functions
"------------------------------------------------------------

" 初期化
function! rogue#initialize()
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
    let s:main_buf_num = bufnr('%')

    " 設定変更
    setlocal noswapfile lazyredraw
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8
    setlocal nocursorline nofoldenable

    " ステータス行を確保 TODO:ステータス行捜査関数作成
    execute 'normal! ' . s:status_line_size . 'i '

    " マップオブジェクト作成
    let s:map_obj = objects#get_new_object('map_obj', s:load_map_data_file('rogue_map.txt'))

    " ステータス行の高さ分を調節
    for obj in s:map_obj.objs
        let obj.now_place.lnum += s:status_line_size
    endfor

    " マップデータ配置 TODO:関数化
    call append(s:status_line_size, s:map_obj.field)

    " 自機オブジェクト作成
    let s:player_obj = objects#get_new_object('player_obj', 3, 3)
    call cursor(3, 3)
    execute 'normal! r'.s:player_obj.obj_info.ICON

    call s:change_buf_modifiable(s:main_buf_num, 0)

    redraw!

    call s:print_debug_msg('initialized !')
endfunction


" 終了処理
function! rogue#finalize()
    " 保存した設定を復元
    execute 'source' s:stored_session_filename

    call s:print_debug_msg('finalized !')
endfunction


" rogue主処理
function! rogue#rogue_main()
    redraw

    " 主処理
    while 1
        " 文字を取得出来るまで停止
        let in_char_code = getchar()

        if in_char_code != 0
            let in_char = nr2char(in_char_code)

            call s:print_debug_msg('Get char : ' . in_char)

            if in_char ==? 'q'
                " 終了
                break
            elseif (in_char ==# 'h') || (in_char ==# 'j') || (in_char ==# 'k') || (in_char ==# 'l')
                " 移動
                call s:move_player(s:map_obj, s:player_obj, in_char)
            endif
        endif

        " 再描画
        redraw
    endwhile
endfunction

" call s:initialize()
" call s:rogue_main()
" call s:finalize()
