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

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()

" オブジェクトの性質を表す属性コード ビットマスク判定で使用する
let s:OBJ_ATTR_CODE = {
            \ 'PLAYER'      : 0x001,
            \ 'ENEMY'       : 0x002,
            \ 'OBSTACLE'    : 0x004,
            \ 'THROUGH'     : 0x008,
            \ 'ITEM_WEAPON' : 0x010,
            \ 'ITEM_FOOD'   : 0x020,
            \ 'UNKOWN'      : 0xfff,
            \ }
lockvar 3 s:OBJ_ATTR_CODE

" オブジェクトの情報を持つ辞書のリスト
let s:OBJ_IDENTIFIER_LIST = [
            \ {
            \   'NAME'  : 'player',
            \   'ID'    : 101,
            \   'ICON'  : ['@'],
            \   'ATTR'  : s:OBJ_ATTR_CODE.PLAYER,
            \ },
            \ {
            \   'NAME'  : 'road',
            \   'ID'    : 102,
            \   'ICON'  : [' '],
            \   'ATTR'  : s:OBJ_ATTR_CODE.THROUGH,
            \ },
            \ {
            \   'NAME'  : 'wall',
            \   'ID'    : 103,
            \   'ICON'  : ['|', '-'],
            \   'ATTR'  : s:OBJ_ATTR_CODE.OBSTACLE,
            \ },
            \ {
            \   'NAME'  : 'Aa',
            \   'ID'    : 104,
            \   'ICON'  : ['A'],
            \   'ATTR'  : or(s:OBJ_ATTR_CODE.ENEMY, s:OBJ_ATTR_CODE.OBSTACLE),
            \ },
            \ {
            \   'NAME'  : 'Bat',
            \   'ID'    : 105,
            \   'ICON'  : ['B'],
            \   'ATTR'  : or(s:OBJ_ATTR_CODE.ENEMY, s:OBJ_ATTR_CODE.OBSTACLE),
            \ },
            \ {
            \   'NAME'  : 'Cat',
            \   'ID'    : 106,
            \   'ICON'  : ['C'],
            \   'ATTR'  : or(s:OBJ_ATTR_CODE.ENEMY, s:OBJ_ATTR_CODE.OBSTACLE),
            \ },
            \ ]
lockvar 3 s:OBJ_IDENTIFIER_LIST

" ゲームのマップ関連のデータ
" s:map_data_lst[]
" 要素は以下
" {
"   field : []
"   objs : []
" }
" TODO:fieldをランダム生成
let s:map_data_lst = []



"------------------------------------------------------------
" Objects
"------------------------------------------------------------

" 自機オブジェクト
" icon - ユーザを示す文字
" now_place - 前回のカーソル位置情報を保存 {lnum, col, map_obj}
let s:player_obj = {
            \ 'icon' : s:OBJ_IDENTIFIER_LIST[0].ICON[0],
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


" 指定座標に自機アイコンを描画, オブジェクトの持つ座標の更新も行う
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

    " ここで直接書き換えると、オブジェクトの復元が出来ないため
    " 現在(移動前)の座標をローカル変数へ
    let n_lnum = self.now_place.lnum
    let n_col = self.now_place.col

    if a:cmd ==# 'h'
        let n_col = n_col - 1
    elseif a:cmd ==# 'j'
        let n_lnum = n_lnum + 1
    elseif a:cmd ==# 'k'
        let n_lnum = n_lnum - 1
    elseif a:cmd ==# 'l'
        let n_col = n_col + 1
    endif

    " 移動したい座標のにあるオブジェクトデータからアクションを判定
    let obj_data = s:get_obj_data(n_lnum, n_col)
    let attr_bit = obj_data.ATTR

    " ビットマスクで属性を判別
    if and(attr_bit, s:OBJ_ATTR_CODE.THROUGH)
        " 通れるならば、自機を描画
        call s:player_obj.draw_icon(n_lnum, n_col)
    elseif and(attr_bit, s:OBJ_ATTR_CODE.ENEMY)
        " 敵なので攻撃
    endif

    echo obj_data
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
" その際、マップ上の壁以外のオブジェクトを検出しオブジェクト化
" 読み込まれたリストの添字を返す
function! s:load_mapdata(file)
    let filepath = g:rogue_map_data_directly . '/' . a:file

    if !filereadable(filepath)
        throw 'ROGUE-ERROR (cannot read mapdata file)'
        return
    endif

    " マップフィールドデータ読み込み
    let field = readfile(filepath)
    call add(s:map_data_lst, {'field' : field, 'objs' : []})

    call s:print_debug_msg(string((field))

    return len(s:map_data_lst) - 1
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


" 指定座標のオブジェクトデータを取得
function! s:get_obj_data(lnum, col)
    let target = s:get_position_char(a:lnum, a:col)

    for obj in s:OBJ_IDENTIFIER_LIST
        for icon in obj.ICON
            " ターゲットの情報を取得
            if target ==# icon
                let t_data = obj
            endif
        endfor
    endfor

    if !exists('t_data')
        " 不明なオブジェクトを発見
        throw 'ROGUE-ERROR (Detect Unkown Object on Map)'
    endif

    " オブジェクトデータを返す
    return t_data
endfunction

"------------------------------------------------------------
" Main Functions
"------------------------------------------------------------

" 初期化
function! rogue#initialize()
    let obj1 = objects#get_new_object('map_obj')
    let obj2 = objects#get_new_object('map_obj')

    call obj1.init()
    call obj2.init()

    return

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

    " 設定変更
    setlocal noswapfile lazyredraw
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8
    setlocal nocursorline nofoldenable

    " ステータス行分を確保し, 初期のマップデータを配置 TODO:関数化
    execute 'normal! ' . s:status_line_size . 'i '
    call append(s:status_line_size, s:map_data_lst[s:load_mapdata('rogue_map.txt')].field)
    call s:print_debug_msg(string(s:map_data_lst[0]))

    " 自機オブジェクト初期化
    call s:player_obj.init(3, 3)   " マップもランダムに生成するなら開始位置も計算必要ありか

    call s:change_buf_modifiable(s:player_obj.bufnum, 0)

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

" call s:initialize()
" call s:rogue_main()
" call s:finalize()
