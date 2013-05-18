"------------------------------------------------------------
" Commands
"------------------------------------------------------------


" TODO タイトル画面的なのを挟んで、mappingでスタートトリガーを打つ
command! -nargs=0 RogueStart call rogue#initialize() | call rogue#rogue_main() | call rogue#finalize()
