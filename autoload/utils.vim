" 指定座標から一文字取得
function! utils#get_position_char(lnum, col)
    return matchstr(getline(a:lnum), '.', a:col - 1)
endfunction


" 指定したファイル名からデータ読み込み
function! utils#load_map_data_file(file)
    let filepath = g:rogue_map_data_directly . '/' . a:file

    if !filereadable(filepath)
        throw 'ROGUE-ERROR (cannot read mapdata file)'
        return
    endif

    return readfile(filepath)
endfunction


" 指定bufferのmodifiableを切り替える
function! utils#change_buf_modifiable(bufnum, is_modif)
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
