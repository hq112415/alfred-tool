#!/bin/bash
# Alfred Script Filter: 搜索项目并用 IDEA 打开
# 无关键词 → 最近项目 + 所有文件夹
# 有关键词 → 最近项目中筛选 + 文件夹中筛选，合并去重

PROJECT_DIR="/Users/huqiang/soft/java_project"
JETBRAINS_DIR="$HOME/Library/Application Support/JetBrains"
QUERY="${1:-}"
MAX_RESULTS=20

# 读取 IDEA 最近项目路径列表（纯路径，一行一个）
load_recent_projects() {
    local idea_dir
    idea_dir=$(ls -d "$JETBRAINS_DIR"/IntelliJIdea* 2>/dev/null | sort -V | tail -1)
    [ -z "$idea_dir" ] && return
    [ ! -f "$idea_dir/options/recentProjects.xml" ] && return
    grep '<entry key=' "$idea_dir/options/recentProjects.xml" \
        | sed 's/.*key="\([^"]*\)".*/\1/' \
        | sed "s|\\\$USER_HOME\\\$|$HOME|g"
}

# 列出文件夹（仅第一层子目录）
list_dirs() {
    find "$PROJECT_DIR" -mindepth 1 -maxdepth 2 -type d ! -path '*/.*' ! -path '*/node_modules/*' 2>/dev/null
}

# === 构建候选列表（纯路径，一行一个）===
# 先最近项目，后文件夹，用 awk 去重（保持顺序）
build_list() {
    local escaped_query
    escaped_query=$(echo "$QUERY" | sed 's/[.[\*^$()+?{|]/\\&/g')

    if [ -z "$QUERY" ]; then
        # 无关键词：最近项目在前，文件夹在后
        {
            load_recent_projects
            list_dirs
        } | awk '!seen[$0]++'
    else
        # 有关键词：awk 去重 + 只匹配最后一级目录名（避免路径误匹配）
        local query_lower
        query_lower=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
        {
            load_recent_projects
            list_dirs
        } | awk -v q="$query_lower" '
            !seen[$0]++ {
                n = $0
                gsub(/\/+$/, "", n)
                sub(/.*\//, "", n)
                if (index(tolower(n), q) > 0) print $0
            }
        '
    fi
}

# === 输出 XML ===
echo '<items>'
found=0

while IFS= read -r path; do
    [ -z "$path" ] && continue
    name=$(basename "$path")
    found=1
    cat <<EOF
<item arg="$path" valid="yes">
    <title>$name</title>
    <subtitle>$path</subtitle>
    <icon>icon.png</icon>
</item>
EOF
    MAX_RESULTS=$((MAX_RESULTS - 1))
    [ $MAX_RESULTS -le 0 ] && break
done < <(build_list)

if [ "$found" -eq 0 ]; then
    cat <<EOF
<item valid="no">
    <title>未找到匹配项目</title>
    <subtitle>在 $PROJECT_DIR 下没有匹配 "$QUERY" 的项目</subtitle>
    <icon>icon.png</icon>
</item>
EOF
fi

echo '</items>'
