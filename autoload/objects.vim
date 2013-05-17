" 存在しない場合終了
if !exists("g:loaded_vimrogue")
    finish
endif

"------------------------------------------------------------
" オブジェクトのテンプレートから
" 引数として指定されたオブジェクトを生成して返す
" オブジェクト名はスクリプローカルな変数名と同じとする
"------------------------------------------------------------
function! objects#get_new_object(obj_name)
    let var_name = 's:' . a:obj_name

    if !exists(var_name)
        throw 'ROGUE-ERROR (do not exists object)'
    endif

    " コピーして返す
    return deepcopy({ var_name }, 1)
endfunction



"------------------------------------------------------------
" Object - Enemy - 敵のデータを保持するオブジェクト
"------------------------------------------------------------



"------------------------------------------------------------
" Object - Map - 敵やフィールドデータを保持するオブジェクト
"------------------------------------------------------------
let s:map_obj = {
            \ 'field' : [],
            \ 'objs'  : [],
            \ }


function! s:map_obj.add_field(field)
    if type([]) != type(a:field)
        throw 'ROGUE-ERROR (This type Cannot add field)'
    endif

    call add(self.field, a:field)
endfunction


function! s:map_obj.add_obj(obj)
    if type({}) != type(a:obj)
        throw 'ROGUE-ERROR (This type Cannot add obj)'
    endif

    call add(self.objs, a:obj)
endfunction



"------------------------------------------------------------
" Object - Dungeon - Mapオブジェクトを保持管理する
"------------------------------------------------------------
let s:dungeon_obj = {
            \ 'maps' : []
            \ }


function! s:dungeon_obj.add_map(map)
    if type({}) != type(a:map)
        throw 'ROGUE-ERROR (This type Cannot add map)'
    endif

    call add(self.maps, a:map)
endfunction



"------------------------------------------------------------
" Util Functions
"------------------------------------------------------------
