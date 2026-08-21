#!/bin/bash
# 빌드 산출물과 설정의 "계약"을 검사한다.
#
# 컴파일도 통과하고 테스트도 통과하는데 틀릴 수 있는 것들이 있다 — entitlements,
# plist 키, 앱과 위젯의 버전 일치 같은 것. v1.3.0에서 두 번 물렸다.
#   · iCloud 키-값 저장소 entitlement가 빠져서 재설치를 못 건너왔다
#   · 그걸 고친 값이 시뮬레이터에서 앱을 아예 못 뜨게 했다 (실기기·CI는 초록)
#
# 근거: docs/verification.md "계약 검증"
#
#   tools/artifact_check.sh            설정 파일만 검사 (빠르다)
#   tools/artifact_check.sh <앱경로>   서명된 산출물까지 검사
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

FAIL=0
ok()   { printf '  ✅ %s\n' "$1"; }
bad()  { printf '  ❌ %s\n' "$1"; FAIL=1; }
warn() { printf '  ⚠️  %s\n' "$1"; }

PBX=Mosco/Mosco.xcodeproj/project.pbxproj
APP_ENT=Mosco/App/App.entitlements
MAC_ENT=Mosco/App/App-Mac.entitlements
WIDGET_ENT=Mosco/MoscoWidget/MoscoWidget.entitlements
WIDGET_MAC_ENT=Mosco/MoscoWidget/MoscoWidget-Mac.entitlements
INFO=Mosco/App/Info.plist

echo
echo "  산출물·설정 계약 검사"
echo "  ─────────────────────────────────────"

# 1. 앱과 위젯의 버전이 같은가 (다르면 업로드가 거부된다)
echo "  버전"
VERSIONS=$(grep -o 'MARKETING_VERSION = [^;]*' "$PBX" | awk '{print $3}' | grep -v '^1\.0$' | sort -u)
BUILDS=$(grep -o 'CURRENT_PROJECT_VERSION = [^;]*' "$PBX" | awk '{print $3}' | grep -v '^1$' | sort -u)
if [ "$(echo "$VERSIONS" | wc -l | tr -d ' ')" = "1" ]; then
  ok "MARKETING_VERSION 일치 ($VERSIONS)"
else
  bad "MARKETING_VERSION이 갈렸다: $(echo $VERSIONS | tr '\n' ' ')"
fi
if [ "$(echo "$BUILDS" | wc -l | tr -d ' ')" = "1" ]; then
  ok "CURRENT_PROJECT_VERSION 일치 ($BUILDS)"
else
  bad "빌드 번호가 갈렸다: $(echo $BUILDS | tr '\n' ' ')"
fi

# 2. entitlements 필수 키
echo "  entitlements"
need_key() { # 파일, 키, 설명
  if grep -q "$2" "$1" 2>/dev/null; then ok "$3"; else bad "$3 — $1 에 $2 없음"; fi
}
no_key() {
  if grep -q "$2" "$1" 2>/dev/null; then bad "$3 — $1 에 $2 가 있으면 안 된다"; else ok "$3"; fi
}
need_key "$APP_ENT" "com.apple.security.application-groups" "앱: App Group"
need_key "$APP_ENT" "ubiquity-kvstore-identifier"           "앱: iCloud 키-값 저장소"
need_key "$APP_ENT" "icloud-container-identifiers"          "앱: iCloud 컨테이너"
need_key "$APP_ENT" "com.apple.developer.weatherkit"        "앱: WeatherKit"
no_key   "$APP_ENT" "com.apple.security.app-sandbox"        "앱(iOS): 샌드박스 키 없음"
need_key "$MAC_ENT" "com.apple.security.app-sandbox"        "앱(맥): 샌드박스"
need_key "$MAC_ENT" "com.apple.security.network.client"     "앱(맥): 네트워크"
need_key "$MAC_ENT" "personal-information.location"         "앱(맥): 위치"
need_key "$WIDGET_ENT" "com.apple.security.application-groups" "위젯: App Group"
need_key "$WIDGET_MAC_ENT" "com.apple.security.app-sandbox"    "위젯(맥): 샌드박스"

# 3. App Group id가 코드와 같은가
echo "  App Group"
CODE_GROUP=$(grep -o 'appGroupID = "[^"]*"' Mosco/Shared/SharedModelContainer.swift | cut -d'"' -f2)
if grep -q "$CODE_GROUP" "$APP_ENT" && grep -q "$CODE_GROUP" "$WIDGET_ENT"; then
  ok "코드와 entitlements가 같다 ($CODE_GROUP)"
else
  bad "코드의 $CODE_GROUP 가 entitlements와 안 맞는다"
fi

# 4. Info.plist 사용 설명
echo "  Info.plist"
need_key "$INFO" "NSLocationWhenInUseUsageDescription" "위치 사용 설명"
if grep -q "ITSAppUsesNonExemptEncryption" "$INFO"; then
  ok "수출 규정"
else
  warn "수출 규정 키가 없다 — 제출할 때마다 물어본다 (docs/BACKLOG.md)"
fi

# 5. 서명된 산출물 (경로를 줬을 때만)
if [ $# -ge 1 ]; then
  APP="$1"
  echo "  서명된 산출물  $APP"
  if [ ! -d "$APP" ]; then
    bad "그 경로에 .app이 없다"
  else
    ENT=$(codesign -d --entitlements :- "$APP" 2>/dev/null | tr -d '\0')
    if [ -z "$ENT" ]; then
      bad "서명 정보를 못 읽었다 (CODE_SIGNING_ALLOWED=NO로 빌드했나?)"
    else
      for KEY in application-identifier com.apple.security.application-groups; do
        echo "$ENT" | grep -q "$KEY" && ok "산출물: $KEY" || bad "산출물에 $KEY 없음"
      done
      case "$APP" in
        *maccatalyst*)
          echo "$ENT" | grep -q "com.apple.security.app-sandbox" \
            && ok "산출물(맥): 샌드박스" || bad "맥 산출물에 샌드박스가 없다" ;;
      esac
    fi
  fi
fi

echo "  ─────────────────────────────────────"
[ $FAIL -eq 0 ] && echo "  통과" || echo "  실패 — 위의 ❌를 보라"
echo
exit $FAIL
