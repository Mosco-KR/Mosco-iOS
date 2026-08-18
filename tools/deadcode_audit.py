#!/usr/bin/env python3
"""쓰이지 않는 코드를 훑는다.

**왜 직접 만들었나.** periphery(표준 도구)는 이 프로젝트에서 못 쓴다. Xcode 16의
폴더 동기화 그룹(PBXFileSystemSynchronizedRootGroup)을 이해하지 못해 타깃별 소스
목록이 비어버리고, 그 상태로 "No unused code detected"를 낸다. 일부러 죽은 코드를
심어 확인했다 — 그것도 못 잡았다. **거짓 청신호가 아무것도 안 하는 것보다 나쁘다.**

이 스크립트가 보는 것은 다섯이다.

1. 심볼      선언만 있고 부르는 곳이 없는 타입·함수·프로퍼티
2. 죽은 파일  내놓는 심볼이 전부 안 쓰이는 파일
3. 타깃 밖   저장소에는 있지만 어느 타깃도 컴파일하지 않는 파일
4. 이벤트    Analytics에 정의됐지만 아무도 안 보내는 것
5. 에셋      Assets.xcassets에 있지만 코드에서 안 쓰는 것
6. 문자열    문자열 카탈로그에 있지만 코드에 없는 키

**도구는 스스로를 못 믿는다.** 만들고 나서 일부러 죽은 코드를 심어 잡히는지
확인했다. periphery는 그 시험을 통과하지 못해 못 쓴다고 판단했다.

**정답을 주는 도구가 아니다.** 후보를 줄여줄 뿐이고, 각 항목이 정말 불필요한지는
사람이 판단한다. 프로토콜 구현·@main 진입점·KVO 대상처럼 "참조가 없어 보이지만
살아 있는" 것들이 있어서, 아래 ALLOWLIST에 이유와 함께 적어둔다.

    사용법: python3 tools/deadcode_audit.py [--json]
"""

import json
import pathlib
import re
import subprocess
import sys
from collections import defaultdict

REPO = pathlib.Path(__file__).resolve().parent.parent
SRC_ROOTS = ["Mosco/App", "Mosco/Shared", "Mosco/MoscoWidget"]
TEST_ROOT = "Mosco/MoscoTests"

# 참조가 없어 보여도 살아 있는 것들. 지울 때마다 빌드가 깨지고 되돌리게 되므로
# 왜 남기는지를 여기 적는다.
ALLOWLIST = {
    "MoscoWidgetBundle": "@main — 위젯 익스텐션 진입점",
    "AppDelegate": "@main — 앱 진입점",
    "SceneDelegate": "Info.plist가 이름으로 지정하는 씬 델리게이트",
    "daySlotRawValue": "CloudKit 스키마 유지용. 지우면 필드가 사라진다",
    "canBecomeKey": "UIWindow 오버라이드 — 시스템이 부른다",
    "body": "SwiftUI View 프로토콜 요구사항",
    "makeBody": "ViewModifier·ButtonStyle 프로토콜 요구사항",
    "makeUIView": "UIViewRepresentable 프로토콜 요구사항",
    "updateUIView": "UIViewRepresentable 프로토콜 요구사항",
    "makeCoordinator": "UIViewRepresentable 프로토콜 요구사항",
    "placeSubviews": "Layout 프로토콜 요구사항",
    "sizeThatFits": "Layout 프로토콜 요구사항",
    "locationManagerDidChangeAuthorization": "CLLocationManagerDelegate 콜백",
    "locationManager": "CLLocationManagerDelegate 콜백",
    "userNotificationCenter": "UNUserNotificationCenterDelegate 콜백",
    "application": "UIApplicationDelegate 콜백",
    "scene": "UIWindowSceneDelegate 콜백",
    "perform": "AppIntent 프로토콜 요구사항",
    "snapshot": "TimelineProvider 프로토콜 요구사항",
    "timeline": "TimelineProvider 프로토콜 요구사항",
    "placeholder": "TimelineProvider 프로토콜 요구사항",
    "getSnapshot": "TimelineProvider 프로토콜 요구사항",
    "getTimeline": "TimelineProvider 프로토콜 요구사항",
}

DECL_TYPE = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |private |fileprivate |nonisolated |final |@MainActor )*\b(struct|class|enum|protocol|actor)\s+([A-Za-z_]\w*)", re.M)
DECL_FUNC = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |private |fileprivate |nonisolated |static |final |mutating |@MainActor |@discardableResult )*func\s+([a-zA-Z_]\w*)", re.M)
DECL_PROP = re.compile(r"^\s*(?:@\w+(?:\([^)]*\))?\s+)*(?:public |internal |private |fileprivate |nonisolated |static |final |@MainActor |@ObservationIgnored )*(?:let|var)\s+([a-z_]\w*)", re.M)


def swift_files(roots):
    out = []
    for root in roots:
        base = REPO / root
        if base.is_dir():
            out.extend(sorted(base.rglob("*.swift")))
    return out


def word_count(word, blobs):
    pattern = re.compile(rf"\b{re.escape(word)}\b")
    return sum(len(pattern.findall(b)) for b in blobs)


def audit_symbols(files, texts):
    """선언 외에 등장하지 않는 심볼."""
    blobs = list(texts.values())
    found = []
    seen = set()
    for path, text in texts.items():
        for regex, kind in ((DECL_TYPE, "타입"), (DECL_FUNC, "함수"), (DECL_PROP, "프로퍼티")):
            for match in regex.finditer(text):
                name = match.group(2) if regex is DECL_TYPE else match.group(1)
                if name in seen or name in ALLOWLIST or len(name) < 3:
                    continue
                seen.add(name)
                if word_count(name, blobs) <= 1:
                    found.append({
                        "이름": name, "종류": kind,
                        "위치": f"{path.relative_to(REPO)}:{text[:match.start()].count(chr(10)) + 1}",
                    })
    return found


def audit_dead_files(dead_symbols, texts):
    """내놓는 심볼이 **전부** 안 쓰이는 파일.

    예전엔 파일 사이 참조 그래프를 만들어 진입점에서 도달 못 하는 파일을 찾았는데,
    같은 이름을 여러 파일이 선언하면(`color`가 네 파일에 있다) 소유자 판정이 엉켜
    멀쩡한 파일이 죽은 것으로 잡혔다. **틀린 경고를 내는 검사는 곧 무시당한다.**
    그래서 근거가 확실한 것만 본다 — 심볼 검사 결과를 파일별로 모은다.
    """
    dead_by_file = defaultdict(int)
    for item in dead_symbols:
        dead_by_file[item["위치"].rsplit(":", 1)[0]] += 1

    out = []
    for path, text in texts.items():
        rel = str(path.relative_to(REPO))
        if rel not in dead_by_file:
            continue
        declared = len({m.group(2) for m in DECL_TYPE.finditer(text)}
                       | {m.group(1) for m in DECL_FUNC.finditer(text)}
                       | {m.group(1) for m in DECL_PROP.finditer(text)})
        if declared and dead_by_file[rel] >= declared:
            out.append(rel)
    return sorted(out)


def audit_orphan_files():
    """저장소에는 있지만 어느 타깃도 컴파일하지 않는 파일.

    코드가 아니라 **무게**다. 지워도 빌드는 그대로지만 클론할 때마다 따라온다.
    """
    tracked = subprocess.run(
        ["git", "-C", str(REPO), "ls-files"], capture_output=True, text=True
    ).stdout.splitlines()

    compiled_roots = tuple(SRC_ROOTS) + (TEST_ROOT,)
    known_meta = (".github/", "docs/", "tools/", ".claude/", "Mosco/Mosco.xcodeproj/")
    known_files = {
        "README.md", "CLAUDE.md", "CONTRIBUTING.md", "RELEASING.md",
        "PRIVACY.md", ".gitignore",
    }

    out = []
    for f in tracked:
        if f in known_files or f.startswith(known_meta) or f.startswith(compiled_roots):
            continue
        out.append(f)
    return sorted(out)


def audit_analytics(texts):
    """정의만 되고 아무도 안 보내는 이벤트."""
    path = REPO / "Mosco/Shared/Analytics.swift"
    if not path.exists():
        return []
    decl = re.findall(r"^\s*case\s+([a-z]\w*)", path.read_text(), re.M)
    # `case let x`, `case where` 같은 패턴 매칭 구문은 이벤트가 아니다.
    decl = [c for c in decl if c not in {"let", "var", "where", "some", "none"}]
    blobs = [t for p, t in texts.items() if p != path]
    return [c for c in dict.fromkeys(decl) if not re.search(rf"\.{re.escape(c)}\b", "".join(blobs))]


def audit_assets(texts):
    """에셋 카탈로그에 있지만 코드에서 안 쓰는 것."""
    found = []
    blob = "".join(texts.values())
    for catalog in REPO.rglob("*.xcassets"):
        for item in catalog.iterdir():
            if item.suffix not in {".imageset", ".colorset", ".symbolset"}:
                continue
            name = item.stem
            if name in {"AppIcon", "AccentColor"} or f'"{name}"' in blob:
                continue
            found.append(f"{catalog.name}/{item.name}")
    return found


def audit_strings(texts):
    """문자열 카탈로그에 있지만 코드에 없는 키."""
    found = []
    blob = "".join(texts.values())
    for catalog in REPO.rglob("*.xcstrings"):
        try:
            data = json.loads(catalog.read_text())
        except ValueError:
            continue
        for key in data.get("strings", {}):
            if key and key not in blob:
                found.append(f"{catalog.name}: {key}")
    return found


def main():
    files = swift_files(SRC_ROOTS)
    texts = {p: p.read_text(errors="replace") for p in files}

    dead_symbols = audit_symbols(files, texts)
    report = {
        "심볼": dead_symbols,
        "통째로 죽은 파일": audit_dead_files(dead_symbols, texts),
        "타깃 밖 파일": audit_orphan_files(),
        "미발생 이벤트": audit_analytics(texts),
        "미사용 에셋": audit_assets(texts),
        "미사용 문자열": audit_strings(texts),
    }

    if "--json" in sys.argv:
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return

    print(f"대상: Swift {len(files)}파일\n")
    for title, items in report.items():
        print(f"─ {title} ({len(items)}건)")
        if not items:
            print("   없음")
        for item in items:
            if isinstance(item, dict):
                print(f"   {item['종류']}  {item['이름']}  ({item['위치']})")
            else:
                print(f"   {item}")
        print()
    print("이 목록은 후보다. 각 항목이 정말 불필요한지는 사람이 판단한다.")
    print(f"살아 있는데 참조가 없어 보이는 것은 ALLOWLIST에 {len(ALLOWLIST)}건 적어뒀다.")


if __name__ == "__main__":
    main()
