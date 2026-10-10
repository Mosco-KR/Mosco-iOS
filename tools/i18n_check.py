#!/usr/bin/env python3
"""문자열 카탈로그에 빠진 번역이 있는지 본다.

## 왜 필요한가

이 앱은 영어와 일본어를 지원한다(1.4.0). 그런데 `String(localized:)`를 새로 쓰면
Xcode가 카탈로그에 **키만** 만들어 넣고 번역은 비워둔다. 비어 있어도 빌드는 통과하고
한국어 기기에서는 멀쩡하다 — 영어·일본어 기기에서만 한국어가 그대로 뜬다.

2026-10-10에 실제로 그랬다. 할 일 탭과 하루 마무리 알림을 만들면서 들어간 문구
열아홉 개가 전부 번역 없이 나갈 뻔했다. 섹션 머리글('이번 주', '나중'), 디데이
카드, 설정 스위치, 알림 본문까지 — 영어 사용자에게는 앱의 절반이 한국어였을 것이다.

눈으로 잡을 수 있는 종류가 아니다. 언어를 바꿔 켜봐야 보이고, 새 문구가 들어갈
때마다 매번 그래야 한다. 그래서 CI가 센다.

## 쓰는 법

    python3 tools/i18n_check.py

빠진 게 있으면 그 목록을 찍고 1을 돌려준다.
"""

import json
import sys
from pathlib import Path

CATALOG = Path(__file__).resolve().parent.parent / "Mosco" / "Shared" / "Localizable.xcstrings"

# 번역을 요구할 언어. 카탈로그의 원문 언어(en)는 값이 없어도 키 자체가 영어면
# 되는 경우가 있지만, 이 앱은 키가 한국어라 영어도 반드시 있어야 한다.
REQUIRED = ("en", "ja", "ko")

# 번역할 것이 없는 문구. 숫자나 기호만 있어서 어느 언어에서나 같다.
# **예외를 늘릴 때는 이유를 적는다** — 적을 이유가 없으면 대개 번역해야 하는 것이다.
EXEMPT = {
    "%lld": "숫자 하나. 섹션 머리글의 개수 표시다",
    # 아래 둘은 번역할 것이 없기도 하지만, **번역을 넣으면 빌드가 깨진다** —
    # 카탈로그에 번역을 달면 Xcode가 그 키로 Swift 심볼을 만들려 하는데,
    # `D+%lld`와 `D-%lld`는 같은 심볼 이름이 되어 서로 충돌한다. 비워두면
    # 키가 그대로 쓰이고, "D-5"·"D+3"은 어느 언어에서나 같은 말이다.
    "D+%lld": "숫자만 바뀌는 표기. 번역을 달면 D-%lld와 심볼이 충돌한다",
    "D-%lld": "숫자만 바뀌는 표기. 번역을 달면 D+%lld와 심볼이 충돌한다",
}


def main() -> int:
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    strings = data.get("strings", {})

    missing: list[tuple[str, list[str]]] = []
    for key, entry in sorted(strings.items()):
        if key in EXEMPT:
            continue
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        gaps = [
            lang
            for lang in REQUIRED
            if localizations.get(lang, {}).get("stringUnit", {}).get("state") != "translated"
        ]
        if gaps:
            missing.append((key, gaps))

    if not missing:
        print(f"번역 검사 통과 — 문구 {len(strings)}개, 빠진 것 없음")
        return 0

    print(f"번역이 빠진 문구 {len(missing)}개:\n")
    for key, gaps in missing:
        preview = key if len(key) <= 50 else key[:47] + "…"
        print(f"  {preview}\n    빠진 언어: {', '.join(gaps)}")
    print(
        "\nXcode에서 Localizable.xcstrings를 열어 채우거나, 번역할 것이 없는 문구면"
        "\ntools/i18n_check.py의 EXEMPT에 이유와 함께 적는다."
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
