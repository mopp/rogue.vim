" 存在しない場合終了
if !exists("g:loaded_vimrogue")
    finish
endif

"--------------------------------------------------------------------
" オブジェクトのテンプレートから
" 引数として指定されたオブジェクトを生成して返す
" オブジェクト名はスクリプローカルな変数名と同じとする
"--------------------------------------------------------------------
function! objects#get_new_object(obj_name, ...)
    let var_name = 's:' . a:obj_name

    if !exists(var_name)
        throw 'ROGUE-ERROR (do not exists object)'
    endif

    " 初期化が必要なら引数を可変個渡す
    " 引数なしの初期化は変数宣言時に行うこと
    if exists('*' . var_name . '.init')
        if a:0 == 0
            throw 'ROGUE-ERROR (Require arguments of ' . a:obj_name . ')'
        endif

        " 初期化実行
        call call({ var_name }.init, a:000, { var_name })
    endif

    " コピーして返す
    return deepcopy({ var_name }, 1)
endfunction



"--------------------------------------------------------------------
" Attribute - そのデータの性質を表す ビットマスク判定で使用する
"--------------------------------------------------------------------
let s:OBJ_ATTR_BIT = {
            \ 'PLAYER'      : 0x001,
            \ 'ENEMY'       : 0x002,
            \ 'OBSTACLE'    : 0x004,
            \ 'THROUGH'     : 0x008,
            \ 'ITEM_WEAPON' : 0x010,
            \ 'ITEM_FOOD'   : 0x020,
            \ 'UNKOWN'      : 0xfff,
            \ }
lockvar 3 s:OBJ_ATTR_CODE


function! objects#get_attr_bit(attr_name)
    if !exists('s:OBJ_ATTR_BIT.' . a:attr_name)
        throw 'ROGUE-ERROR (Not exists attribute'
    endif

    return s:OBJ_ATTR_BIT[ a:attr_name ]
endfunction



"--------------------------------------------------------------------
" Identifier - オブジェクトの情報を持つ辞書のリスト
"--------------------------------------------------------------------
let s:OBJ_DATA_LIST = [
            \ {
            \   'NAME'    : 'player',
            \   'ID'      : 101,
            \   'ICON'    : ['@'],
            \   'ATTR'    : s:OBJ_ATTR_BIT.PLAYER,
            \ },
            \ {
            \   'NAME'    : 'road',
            \   'ID'      : 102,
            \   'ICON'    : [' '],
            \   'ATTR'    : s:OBJ_ATTR_BIT.THROUGH,
            \ },
            \ {
            \   'NAME'    : 'wall',
            \   'ID'      : 103,
            \   'ICON'    : ['|', '-'],
            \   'ATTR'    : s:OBJ_ATTR_BIT.OBSTACLE,
            \ },
            \ {
            \   'NAME'    : 'Aa',
            \   'ID'      : 104,
            \   'ICON'    : ['A'],
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 0,
            \   'ATTACK'  : 0,
            \   'DEFENSE' : 0,
            \ },
            \ {
            \   'NAME'    : 'Bat',
            \   'ID'      : 105,
            \   'ICON'    : ['B'],
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 0,
            \   'ATTACK'  : 0,
            \   'DEFENSE' : 0,
            \ },
            \ {
            \   'NAME'    : 'Cat',
            \   'ID'      : 106,
            \   'ICON'    : ['C'],
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 0,
            \   'ATTACK'  : 0,
            \   'DEFENSE' : 0,
            \ },
            \ ]
lockvar 3 s:OBJ_IDENTIFIER_LIST



"--------------------------------------------------------------------
" Object - Enemy - 敵のデータを保持するオブジェクト
"--------------------------------------------------------------------
let s:enemy_obj = {
            \ 'init_data' : {},
            \ 'life'      : 0,
            \ 'attack'    : 0,
            \ 'defense'   : 0,
            \ 'now_place' : {
            \     'lnum'    : -1,
            \     'col'     : -1,
            \     'map_obj' : ' ',
            \ },
            \ }


function! s:enemy_obj.init(name, lnum, col)


    " 位置設定
    let self.now_place.lnum = a:lnum
    let self.now_place.col = a:col
endfunction


"--------------------------------------------------------------------
" Object - Map - 敵やフィールドデータを保持するオブジェクト
"--------------------------------------------------------------------
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



"--------------------------------------------------------------------
" Object - Dungeon - Mapオブジェクトを保持管理する
"--------------------------------------------------------------------
let s:dungeon_obj = {
            \ 'maps' : []
            \ }


function! s:dungeon_obj.add_map(map)
    if type({}) != type(a:map)
        throw 'ROGUE-ERROR (This type Cannot add map)'
    endif

    call add(self.maps, a:map)
endfunction
