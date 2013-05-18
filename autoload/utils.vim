" 指定座標から一文字取得
function! utils#get_position_char(lnum, col)
    return matchstr(getline(a:lnum), '.', a:col - 1)
endfunction
