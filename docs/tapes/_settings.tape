# 全部の操作スクリプトが最初に Source で読む端末の設定（これ自体は録画しない。make screens は _ で始まるものを飛ばす）
# 100 桁 × 30 行になる（docs/tapes/_size.tape で確かめられる）。
# 環境変数は docs/tapes/_env.tape に分けてある。Env の後ろに置いた Set は VHS が無視するため。
Set Shell "bash"
Set FontFamily "Noto Sans Mono CJK JP"
Set FontSize 16
Set Width 945
Set Height 750
Set Padding 10
Set TypingSpeed 40ms
Set Theme "Builtin Dark"
