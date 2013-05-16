"------------------------------------------------------------
" Map
"------------------------------------------------------------
let s:map_obj = {
            \ 'field' : []
            \ }

let s:cnt = 0
function! s:map_obj.init()
endfunction



"------------------------------------------------------------
" Util Functions
"------------------------------------------------------------

function! s:init_map_obj()
endfunction



"------------------------------------------------------------
" 指定されたオブジェクトを生成して返す
" オブジェクト名は欲しい、スクリプローカルな変数名と同じとする
"------------------------------------------------------------

function! objects#get_new_object(obj_name)
    let var_name = 's:' . a:obj_name

    if !exists(var_name)
        throw 'ROGUE-ERROR (do not exists object)'
    endif

    " コピーして返す
    return eval('deepcopy(' . var_name . ', 1)')
endfunction
