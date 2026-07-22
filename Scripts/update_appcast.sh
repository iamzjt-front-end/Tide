#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "用法: Scripts/update_appcast.sh <dmg-path> <release-tag>" >&2
  echo "示例: Scripts/update_appcast.sh /tmp/Tide-v0.0.2-macos.dmg v0.0.2" >&2
  exit 64
fi

archive_path="${1:A}"
release_tag="$2"
repository_root="${0:A:h:h}"

if [[ ! -f "$archive_path" ]]; then
  echo "找不到更新包: $archive_path" >&2
  exit 66
fi

generate_appcast="${SPARKLE_GENERATE_APPCAST:-}"
if [[ -z "$generate_appcast" ]]; then
  search_roots=(
    "$HOME/Library/Developer/Xcode/DerivedData"
    /tmp
  )
  for search_root in "${search_roots[@]}"; do
    [[ -d "$search_root" ]] || continue
    generate_appcast=$(find "$search_root" \
      -path '*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast' \
      -type f -print -quit 2>/dev/null)
    [[ -n "$generate_appcast" ]] && break
  done
fi

if [[ -z "$generate_appcast" || ! -x "$generate_appcast" ]]; then
  echo "找不到 Sparkle generate_appcast。请先在 Xcode 中解析依赖或设置 SPARKLE_GENERATE_APPCAST。" >&2
  exit 69
fi

work_dir=$(mktemp -d /tmp/TideAppcast.XXXXXX)
trap 'rm -rf "$work_dir"' EXIT
cp "$archive_path" "$work_dir/"

"$generate_appcast" \
  --download-url-prefix "https://github.com/iamzjt-front-end/Tide/releases/download/$release_tag/" \
  --link "https://github.com/iamzjt-front-end/Tide/releases/latest" \
  --maximum-versions 1 \
  "$work_dir"

if ! grep -q 'sparkle:edSignature=' "$work_dir/appcast.xml"; then
  echo "appcast 未包含 EdDSA 签名。请确认 DMG 内的 Tide 使用当前 SUPublicEDKey 构建。" >&2
  exit 65
fi

cp "$work_dir/appcast.xml" "$repository_root/appcast.xml"
echo "已更新 $repository_root/appcast.xml"
echo "请在 Release 资产上传完成后提交并推送 appcast.xml。"
