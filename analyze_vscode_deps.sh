#!/bin/bash

# VSCode拡張機能のnpmパッケージを分析するスクリプト

usage() {
    echo "使い方: $0 [オプション]"
    echo "  -e, --extension EXTENSION    特定の拡張機能のパッケージのみ表示"
    echo "  -d, --days DAYS              指定した日数以内にインストールされたパッケージのみ表示"
    echo "  -s, --search PATTERN         パッケージ名で検索"
    echo "  -o, --old DAYS               指定した日数より古いパッケージを表示"
    echo "  -c, --count                  拡張機能別のパッケージ数を表示"
    echo "  -h, --help                   このヘルプを表示"
    echo ""
    echo "例:"
    echo "  $0 -e ms-toolsai.jupyter     # Jupyter拡張機能のパッケージのみ"
    echo "  $0 -d 30                     # 30日以内にインストールされたパッケージ"
    echo "  $0 -s axios                  # axiosを含むパッケージを検索"
    echo "  $0 -o 365                    # 1年以上古いパッケージ"
    echo "  $0 -c                        # 拡張機能別パッケージ数統計"
}

# デフォルト値
EXTENSION_FILTER=""
DAYS_FILTER=""
SEARCH_PATTERN=""
OLD_DAYS=""
COUNT_MODE=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--extension)
            EXTENSION_FILTER="$2"
            shift 2
            ;;
        -d|--days)
            DAYS_FILTER="$2"
            shift 2
            ;;
        -s|--search)
            SEARCH_PATTERN="$2"
            shift 2
            ;;
        -o|--old)
            OLD_DAYS="$2"
            shift 2
            ;;
        -c|--count)
            COUNT_MODE=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "不明なオプション: $1"
            usage
            exit 1
            ;;
    esac
done

echo "VSCode拡張機能のnpmパッケージ分析"
echo "=================================="

# 一時ファイル
temp_file=$(mktemp)

# パッケージ情報を収集
find ~/.vscode/extensions -name "node_modules" -type d | while read node_modules_dir; do
    if [ -d "$node_modules_dir" ]; then
        find "$node_modules_dir" -maxdepth 1 -type d -name "[^.]*" | while read package_dir; do
            package_json="$package_dir/package.json"
            if [ -f "$package_json" ]; then
                package_name=$(basename "$package_dir")
                install_time=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$package_dir" 2>/dev/null)
                install_timestamp=$(stat -f "%B" "$package_dir" 2>/dev/null)
                extension_name=$(echo "$node_modules_dir" | sed 's|.*/\.vscode/extensions/||' | sed 's|/.*||')
                version=$(grep '"version"' "$package_json" 2>/dev/null | head -1 | sed 's/.*"version".*"\([^"]*\)".*/\1/')
                echo "$install_timestamp|$install_time|$extension_name|$package_name|$version"
            fi
        done
    fi
done | sort -n > "$temp_file"

# カウントモードの場合
if [ "$COUNT_MODE" = true ]; then
    echo "拡張機能別パッケージ数:"
    echo "----------------------"
    awk -F'|' '{count[$3]++} END {for (ext in count) printf "%-50s %d\n", ext, count[ext]}' "$temp_file" | sort -k2 -nr
    echo
    echo "総拡張機能数: $(awk -F'|' '{ext[$3]=1} END {print length(ext)}' "$temp_file")"
    echo "総パッケージ数: $(wc -l < "$temp_file")"
    rm "$temp_file"
    exit 0
fi

# フィルタリング
current_timestamp=$(date +%s)

while IFS='|' read -r install_timestamp install_time extension_name package_name version; do
    # 拡張機能フィルタ
    if [ -n "$EXTENSION_FILTER" ] && [[ "$extension_name" != *"$EXTENSION_FILTER"* ]]; then
        continue
    fi

    # パッケージ名検索
    if [ -n "$SEARCH_PATTERN" ] && [[ "$package_name" != *"$SEARCH_PATTERN"* ]]; then
        continue
    fi

    # 日数フィルタ（最近のパッケージ）
    if [ -n "$DAYS_FILTER" ]; then
        days_ago=$((current_timestamp - DAYS_FILTER * 86400))
        if [ "$install_timestamp" -lt "$days_ago" ]; then
            continue
        fi
    fi

    # 古いパッケージフィルタ
    if [ -n "$OLD_DAYS" ]; then
        days_ago=$((current_timestamp - OLD_DAYS * 86400))
        if [ "$install_timestamp" -gt "$days_ago" ]; then
            continue
        fi
    fi

    echo "$install_time|$extension_name|$package_name|$version"
done < "$temp_file" > "${temp_file}_filtered"

# 結果表示
echo
printf "%-20s %-40s %-30s %-10s\n" "インストール日時" "拡張機能" "パッケージ名" "バージョン"
echo "--------------------------------------------------------------------------------------------------------"

while IFS='|' read -r install_time extension_name package_name version; do
    printf "%-20s %-40s %-30s %-10s\n" "$install_time" "${extension_name:0:39}" "${package_name:0:29}" "${version:0:9}"
done < "${temp_file}_filtered"

echo
echo "表示パッケージ数: $(wc -l < "${temp_file}_filtered")"

# 一時ファイルを削除
rm "$temp_file" "${temp_file}_filtered"
