# 按 Markdown 代码块规则读文件的公共函数，由各 tests/*.test.sh 用 source 引入；只定义变量和函数。
# 代码块规则：N（N>=3）个反引号开头的行打开代码块；块里反引号个数 >= N 且后面只有空白的行才关闭。
# 围栏行本身算代码块里的行；代码块里的行不算标题、起始行、结束行、匹配行。
# 字符串经环境变量传给 awk，避免 -v 解释反斜杠。

# awk 规则文本：放在程序最前面，每行把 cb 设为 1（围栏行或代码块内）或 0，不输出、不跳过行
MD_CB_AWK='{ cb = (fence > 0) } /^```/ { match($0, /^`+/); k = RLENGTH; if (!fence) { fence = k; cb = 1 } else if (k >= fence && $0 ~ /^`+[ \t]*$/) { fence = 0; cb = 1 } }'

# md_section FILE START [STOP]：FILE 为路径或 -。从代码块外第一个以 START 开头的行起（含），
# 到下一个代码块外匹配 ERE STOP 的行之前；省略 STOP 时，到下一个级别不低于 START 的 # 标题之前
md_section() {
  MD_START="$2" MD_STOP="${3:-}" awk "$MD_CB_AWK"'
    BEGIN { start = ENVIRON["MD_START"]; stop = ENVIRON["MD_STOP"]; n = 0; if (stop == "") while (substr(start, n + 1, 1) == "#") n++ }
    !cb && found && stop != "" && $0 ~ stop { exit }
    !cb && found && stop == "" && match($0, /^#+ /) && RLENGTH - 1 <= n { exit }
    !cb && !found && index($0, start) == 1 { found = 1 }
    found { print }
  ' "$1" 2>/dev/null || true
}

# md_line FILE TEXT [exact]：代码块外第一个以 TEXT 开头（exact 时整行相等）的行号
md_line() {
  MD_TEXT="$2" MD_EXACT="${3:-}" awk "$MD_CB_AWK"'
    BEGIN { t = ENVIRON["MD_TEXT"]; exact = (ENVIRON["MD_EXACT"] == "exact") }
    !cb && (exact ? $0 == t : index($0, t) == 1) { print NR; exit }
  ' "$1" 2>/dev/null || true
}

# md_grep_n FILE ERE：代码块外匹配 ERE 的行，输出 行号:内容
md_grep_n() {
  MD_RE="$2" awk "$MD_CB_AWK"'
    BEGIN { re = ENVIRON["MD_RE"] }
    !cb && $0 ~ re { print NR ":" $0 }
  ' "$1" 2>/dev/null || true
}
