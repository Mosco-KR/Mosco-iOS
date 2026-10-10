#!/bin/bash
# 스토어 미리보기 원본을 세 언어로 찍는다.
#
# 손으로 찍으면 언어마다 열두 번 같은 일을 반복하게 되고, 그 중 한 번은 상태 바를
# 9:41로 안 맞추거나 저장소를 안 비운 채로 찍는다. 그래서 한 줄로 묶었다.
#
#   tools/capture_screenshots.sh
#
# 결과는 store/raw/<언어>_<번호>_<장면>.png 로 떨어진다. 1320×2868 원본이고,
# 여기에 문구와 배경을 입히는 것은 합성 단계가 맡는다.
#
# 앱을 먼저 빌드해 둬야 한다 (CLAUDE.md의 빌드 명령). 이 스크립트는 빌드하지 않고
# DerivedData에 있는 결과물을 가져다 설치한다 — 빌드까지 묶으면 한 번 돌리는 데
# 몇 분이 걸려서, 찍기만 다시 하고 싶을 때 쓸 수 없다.
set -euo pipefail

DEVICE="${MOSCO_DEVICE:-iPhone 17 Pro}"
BUNDLE_ID="com.Mosco.App"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/store/raw"

# UDID를 박아 쓰지 않는다 — 시뮬레이터는 지워지고 다시 생긴다. 이름으로 찾는다.
echo "▸ 시뮬레이터: $DEVICE"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b >/dev/null

APP_DIR="$(xcodebuild -project "$ROOT/Mosco/Mosco.xcodeproj" -scheme App \
    -sdk iphonesimulator -destination "platform=iOS Simulator,name=$DEVICE" \
    -showBuildSettings 2>/dev/null \
    | awk -F' = ' '/ BUILT_PRODUCTS_DIR = /{print $2; exit}')"
APP="$APP_DIR/App.app"
[ -d "$APP" ] || { echo "✗ 빌드 결과물이 없다: $APP" >&2; exit 1; }

echo "▸ 설치: $APP"
xcrun simctl install "$DEVICE" "$APP"

# 상태 바를 고정한다. 안 하면 찍을 때마다 시계와 배터리가 달라서 넉 장이 서로 안 맞는다.
xcrun simctl status_bar "$DEVICE" override \
    --time "9:41" --batteryState charged --batteryLevel 100 \
    --cellularBars 4 --wifiBars 3

mkdir -p "$OUT"

# 장면 = 출력이름:실행인자. 순서가 곧 스토어에 올라가는 순서다.
# docs/STORE.md의 '미리보기 문구' 표와 같은 순서여야 한다.
SHOTS=(
    "1_compose:-MoscoScreenshot compose"
    "2_todos:-MoscoScreenshot todos"
    "3_month:-MoscoScreenshot month"
    "4_timeline:-MoscoScreenshot today -dayViewMode timeline"
)

for lang in ${MOSCO_LANGS:-ko en ja}; do
    case "$lang" in
        ko) locale="ko_KR" ;;
        en) locale="en_US" ;;
        ja) locale="ja_JP" ;;
    esac

    for shot in "${SHOTS[@]}"; do
        name="${shot%%:*}"
        args="${shot#*:}"

        # 앱을 내리고 저장소를 비운 채 다시 띄운다. `-MoscoResetStore`는 빈 저장소에서만
        # 예시를 채우므로, 안 내리면 앞 언어의 할 일이 그대로 남는다.
        xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
        # shellcheck disable=SC2086
        xcrun simctl launch "$DEVICE" "$BUNDLE_ID" \
            -MoscoResetStore $args \
            -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null

        # 화면이 그려질 때까지 기다린다. 시드가 열일곱 개를 넣고 달력이 한 달치를
        # 다시 그리는 시간이라, 너무 짧으면 빈 화면이 찍힌다.
        sleep 9
        xcrun simctl io "$DEVICE" screenshot "$OUT/${lang}_${name}.png" >/dev/null
        echo "  ✓ ${lang}_${name}.png"
    done
done

xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
echo "▸ 끝. $OUT 에 $(ls -1 "$OUT" | wc -l | tr -d ' ')장"
