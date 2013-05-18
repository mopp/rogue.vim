" 存在しない場合終了
if !exists("g:loaded_vimrogue")
    finish
endif

"--------------------------------------------------------------------
" Global Functions
"--------------------------------------------------------------------
" オブジェクトのテンプレートから
" 引数として指定されたオブジェクトを生成して返す
" オブジェクト名はスクリプローカルな変数名と同じとする
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
" Obj_Info - オブジェクトの情報を持つ辞書のリスト 名前の重複は禁止
"--------------------------------------------------------------------
let s:OBJ_INFO_LIST = [
            \ {
            \   'NAME'    : 'player',
            \   'ID'      : 101,
            \   'ICON'    : '@',
            \   'ATTR'    : s:OBJ_ATTR_BIT.PLAYER,
            \ },
            \ {
            \   'NAME'    : 'road',
            \   'ID'      : 102,
            \   'ICON'    : ' ',
            \   'ATTR'    : s:OBJ_ATTR_BIT.THROUGH,
            \ },
            \ {
            \   'NAME'    : 'wall1',
            \   'ID'      : 103,
            \   'ICON'    : '|',
            \   'ATTR'    : s:OBJ_ATTR_BIT.OBSTACLE,
            \ },
            \ {
            \   'NAME'    : 'wall2',
            \   'ID'      : 104,
            \   'ICON'    : '-',
            \   'ATTR'    : s:OBJ_ATTR_BIT.OBSTACLE,
            \ },
            \ {
            \   'NAME'    : 'Acute',
            \   'ID'      : 105,
            \   'ICON'    : 'A',
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 10,
            \   'ATTACK'  : 4,
            \   'DEFENSE' : 3,
            \ },
            \ {
            \   'NAME'    : 'Bat',
            \   'ID'      : 106,
            \   'ICON'    : 'B',
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 20,
            \   'ATTACK'  : 4,
            \   'DEFENSE' : 2,
            \ },
            \ {
            \   'NAME'    : 'Cat',
            \   'ID'      : 107,
            \   'ICON'    : 'C',
            \   'ATTR'    : or(s:OBJ_ATTR_BIT.ENEMY, s:OBJ_ATTR_BIT.OBSTACLE),
            \   'LIFE'    : 15,
            \   'ATTACK'  : 5,
            \   'DEFENSE' : 4,
            \ },
            \ ]
lockvar 3 s:OBJ_INFO_LIST


function! objects#get_obj_info_by_name(obj_name)
    " 浅い参照を使って、検索し一致した辞書を持つ、リストを取得
    let obj_info = filter(copy(s:OBJ_INFO_LIST), 'v:val["NAME"] ==? "' . a:obj_name . '"')

    if len(obj_info) == 0
        throw 'ROGUE-ERROR (Not exists object info'
    endif

    " 重複は禁止なので0番目の要素を返す
    return obj_info[0]
endfunction



"--------------------------------------------------------------------
" Object - Enemy - 敵のデータを保持するオブジェクト
"--------------------------------------------------------------------
let s:enemy_obj = {
            \ 'obj_info'  : {},
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
    " 初期値設定
    let obj_info = objects#get_obj_info_by_name(a:name)

    " Enemy属性を持つかどうか判定
    if and(objects#get_attr_bit('ENEMY'), obj_info.ATTR) == 0
        throw 'ROGUE-ERROR (It is Not Enemy)'
    endif

    let s:enemy_obj.obj_info = obj_info

    " 位置設定
    let self.now_place.lnum = a:lnum
    let self.now_place.col = a:col

    " そのオブジェクトの初期データを設定
    let self.life = obj_info.LIFE
    let self.attack = obj_info.ATTACK
    let self.defense = obj_info.DEFENSE
endfunction



"--------------------------------------------------------------------
" Object - Map - 敵やフィールドデータを保持するオブジェクト
"--------------------------------------------------------------------
let s:map_obj = {
            \ 'field' : [],
            \ 'objs'  : [],
            \ }


function! s:map_obj.init(field)
    if type([]) != type(a:field)
        throw 'ROGUE-ERROR (This type Cannot add field)'
    endif

    let self.field = deepcopy(a:field)

    " 行番号は1から
    let line_num = 1

    " マップを捜査してオブジェクトを作成
    for line in self.field
        " 文字列をリニアサーチ
        for i in range(strlen(line))
            for obj in s:OBJ_INFO_LIST
                " 発見したらオブジェクトを作成する
                if line[i] ==# obj.ICON
                    " ビットマスク判定
                    if and(obj.ATTR, objects#get_attr_bit('ENEMY'))
                        " 敵オブジェクト作成
                        call s:map_obj.add_obj(objects#get_new_object('enemy_obj', obj.NAME, line_num, i + 1))
                    endif
                endif
            endfor
        endfor

        let line_num += 1
    endfor
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
