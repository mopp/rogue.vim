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

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()

" 使用するバッファ番号
let s:main_buf_num = -1

" ゲームのマップデータ listの入れ子 TODO:ランダムで生成
let s:mapdata_lst = []

"------------------------------------------------------------
" Functions
"------------------------------------------------------------

" for debug.
function! s:print_debug_msg(msg)
    if s:DEBUG_FLAG
        echomsg a:msg
    endif
endfunction


" 初期化
function! s:initialize()
    " 現在のセッションを保存
    execute 'mksession!' s:stored_session_filename

    " 1番のwindowsに移動
    1 wincmd w

    " windowを作成
    silent! new
    silent! file VIM-ROGUE

    " buffer番号を保存
    let s:main_buf_num = bufnr('%')

    " 現在windowのみに
    only

    " 設定変更
    setlocal bufhidden=delete buftype=nofile nolist noreadonly noswapfile textwidth=0 nowrap

    " 初期のマップデータを配置
    call append(0, s:mapdata_lst[s:load_mapdata('rogue_map.txt')])
    call cursor(2, 2)

    augroup rogue
        autocmd CursorMoved VIM-ROGUE call s:rogue_main()
        autocmd InsertEnter VIM-ROGUE normal! '<ESC>'
        autocmd InsertEnter VIM-ROGUE echo 'insert enter'
    augroup END

    call s:print_debug_msg('initialized !')
endfunction


" 終了処理
function! s:finalize()
    " 保存した設定を復元
    execute 'source' s:stored_session_filename

    call s:print_debug_msg('finalized !')
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

" rogueのメインループ
let s:loop_cnt = 0
function! s:rogue_main()
    call s:print_debug_msg('main cnt = ' + s:loop_cnt)
    let s:loop_cnt = s:loop_cnt + 1
endfunction



call s:initialize()
" call s:finalize()
