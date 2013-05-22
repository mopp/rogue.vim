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
let s:status_line_size = 2
lockvar s:status_line_size

" ステータス行のprintf関数用フォーマット
" let s:status_line_format = 'Player[ HP]'

" 使用するbuffer名
let s:main_buf_name = '==ROGUE=='
lockvar s:main_buf_name

" 使用するbuffer番号
let s:main_buf_num = 0

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()
lockvar s:stored_session_filename

" 自機オブジェクト
" TODO: 自分いるmapへの参照を追加して
" オブジェクト側で移動などを行う？
let s:player_obj = {}

" マップについてのデータを持つオブジェクト TODO:dungeonに変更
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


" 自機を移動
function! s:move_player(map, player, cmd)
    " ここで直接書き換えると、オブジェクトの復元が出来ないため 現在(移動前)の座標を別変数へ
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

    " オブジェクトの属性ビット取得
    let attr_bit = t_obj.obj_info.ATTR

    " ビットマスクで属性を判別
    if 0 != and(attr_bit, objects#get_attr_bit('THROUGH'))
        " 移動
        call a:player.move(n_lnum, n_col)

        call s:update_status_line()
    elseif 0 != and(attr_bit, objects#get_attr_bit('ENEMY'))
        " 攻撃
        let t_obj.life -= float2nr(a:player.attack - t_obj.defense * 0.5)
        let a:player.life -= float2nr(t_obj.attack - a:player.defense * 0.3)

        " ステータス行描画
        let info = t_obj.obj_info
        let status_str = printf('[Enemy] - Name:%s, Life:%d/%d, Attak:%d, Defense:%d',
                    \ info.NAME,
                    \ t_obj.life,
                    \ info.LIFE,
                    \ t_obj.attack,
                    \ t_obj.defense,
                    \ )

        " 倒された場合
        if a:player.life <= 0
            return -1
        endif

        " 倒した場合
        if t_obj.life <= 0
            " 敵の防御分回復
            let a:player.life += t_obj.defense

            " 倒したので敵オブジェクトを削除
            call a:map.delete_obj(t_obj)
            call cursor(n_lnum, n_col)
            execute 'normal! r '

            let status_str = 'Enemy Down !'

            " 移動
            call a:player.move(n_lnum, n_col)
        endif

        call s:update_status_line(status_str)
    endif

    return 0
endfunction


" 敵を移動
function! s:move_enemy(map, player_place)
    let p_col = a:player_place.lnum
    let p_lnum = a:player_place.col

    " 各敵に対して以下を確認
    "  - 自機に対し直線距離にて一定距離以下か
    "  - 一定距離以下の時、移動可能か
    " 敵のみを抜き出すためfilterを使用
    for enemy in filter(copy(a:map.objs), 'and(v:val["obj_info"]["ATTR"], ' . objects#get_attr_bit('ENEMY') . ')')
        let e_col = enemy.now_place.col
        let e_lnum = enemy.now_place.lnum

        let calc_col = p_col - e_col
        let calc_lnum = p_lnum - e_lnum

        " 三平方の定理より、自機との距離を計算
        let diff_pos = float2nr(sqrt(calc_col * calc_col + calc_lnum * calc_lnum))

        " 一定以上離れているので移動しない
        if 10 < diff_pos
            continue
        endif

        " 移動先設定
        if abs(calc_lnum) < abs(calc_col)
            let e_lnum += (e_lnum < p_lnum)?1:-1
        else
            let e_lnum += (e_col < p_col)?1:-1
        endif

        " 移動したい座標のオブジェクト取得
        let t_obj = a:map.get_obj(e_lnum, e_col)

        " オブジェクトの属性ビット取得
        let attr_bit = t_obj.obj_info.ATTR

        " ビットマスクで属性を判別
        if 0 != and(attr_bit, objects#get_attr_bit('THROUGH'))
            " 移動
            call enemy.move(e_lnum, e_col)

            call s:update_status_line()
        elseif 0 != and(attr_bit, objects#get_attr_bit('PLAYER'))
            " 攻撃
        endif
    endfor
endfunction


" ステータス行を更新
" 引数があれば順に末尾に追加する
function! s:update_status_line(...)
    let saved_cursor = getpos('.')

    " call utils#change_buf_modifiable(s:main_buf_num, 1)

    " 書き換えるため削除
    execute 'normal! gg' . s:status_line_size . 'dd'

    let info = s:player_obj.obj_info
    let status_str_lst  = []
    call add(status_str_lst, printf('[Player] - Life:%d/%d, Attak:%d, Defense:%d, [%s]',
                \ s:player_obj.life,
                \ info.LIFE,
                \ s:player_obj.attack,
                \ s:player_obj.defense,
                \ ((s:player_obj.now_place.map_obj == ' ')?('Nothing'):('Anythimg'))
                \ ))

    " 追加の表示を可変引数で受け取り
    for str in a:000
        call add(status_str_lst, str)
    endfor

    " 空行埋め
    while len(status_str_lst) < s:status_line_size
        call add(status_str_lst, '')
    endwhile

    if s:status_line_size != len(status_str_lst)
        throw 'ROGUE-ERROR (Over status Line size)'
    endif

    " ステータス行書き込み
    call cursor(1, 1)
    call append(0, status_str_lst)

    " call utils#change_buf_modifiable(s:main_buf_num, 0)

    call setpos('.', saved_cursor)
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

    " 自機オブジェクト作成
    let s:player_obj = objects#get_new_object('player_obj', s:status_line_size + 2, 3)

    " ステータス行描画
    execute 'normal! ' . s:status_line_size . 'i '
    call s:update_status_line()
    " call utils#change_buf_modifiable(s:main_buf_num, 1)

    " マップオブジェクト作成
    let s:map_obj = objects#get_new_object('map_obj', utils#load_map_data_file('rogue_map.txt'))

    " ステータス行の高さ分を調節
    for obj in s:map_obj.objs
        let obj.now_place.lnum += s:status_line_size
    endfor

    " マップデータ配置 TODO:関数化
    call append(s:status_line_size, s:map_obj.field)

    " 自機描画 ステータス行とマップの関係上ここで描画
    call cursor(s:status_line_size + 2, 3)
    execute 'normal! r'.s:player_obj.obj_info.ICON

    " call utils#change_buf_modifiable(s:main_buf_num, 0)

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
                " 体力を回復
                if s:player_obj.life < s:player_obj.obj_info.LIFE
                    let s:player_obj.life += 1
                endif

                " 自機位置をから敵を移動
                call s:move_enemy(s:map_obj, s:player_obj.now_place)

                " 移動
                if -1 == s:move_player(s:map_obj, s:player_obj, in_char)
                    " Game Over
                    echo 'Game Over !'
                    sleep 3
                    break
                endif
            endif
        endif

        " 再描画
        redraw
    endwhile
endfunction

" call s:initialize()
" call s:rogue_main()
" call s:finalize()
