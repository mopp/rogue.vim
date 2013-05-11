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

let s:debug_main_cnt = 0

" 起動前の状態保存用のファイル名
let s:stored_session_filename = tempname()

" 使用するバッファ番号
let s:main_buf_num = -1

" ゲームのマップデータ listの入れ子
" TODO:ランダムで生成, mapデータ用のディレクトリを決めて一括読み込み
let s:mapdata_lst = []



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
    execute 'mksession!' s:stored_session_filename
    call writefile(['set bg='.&bg, 'colorscheme ' . g:colors_name], s:stored_session_filename . 'x.vim')

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
    setlocal bufhidden=delete buftype=nofile modifiable
    setlocal nolist noreadonly noswapfile textwidth=0 nowrap
    setlocal fileencodings=utf-8 fileencoding=utf-8

    " mapping定義
    call s:define_mappings()

    " 初期のマップデータを配置
    call append(0, s:mapdata_lst[s:load_mapdata('rogue_map.txt')])
    call cursor(2, 2)
    call s:change_buf_modifiable(s:main_buf_num, 0)

    augroup rogue
        autocmd CursorMoved VIM-ROGUE call s:rogue_main()
    augroup END

    call s:print_debug_msg('initialized !')
endfunction


" 終了処理
function! s:finalize()
    " 保存した設定を復元
    execute 'source' s:stored_session_filename

    call s:print_debug_msg('finalized !')
endfunction


" rogueのメインループ - CursorMoved にて呼ばれる
function! s:rogue_main()
    " この関数内でのmovedはどうするか
    let coursor_char = matchstr(getline('.'), '.', col('.') - 1)
    echo s:debug_main_cnt . ':' . coursor_char

    let s:debug_main_cnt = s:debug_main_cnt + 1
endfunction



"------------------------------------------------------------
" Commands
"------------------------------------------------------------

" TODO: ユーティリティ系でもいれよう


call s:initialize()
