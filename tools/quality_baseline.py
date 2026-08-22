#!/usr/bin/env python3
"""코드 품질 기준선을 센다.

"지속 가능한 코드인가"는 느낌이라 그대로 두면 판정이 매번 달라진다. 셀 수 있는
것만이라도 매번 같은 방법으로 세서, 리팩터링 전후를 비교할 수 있게 한다.

근거: docs/verification.md "품질 검증을 어떻게 셀 것인가"
기준선: docs/architecture/CURRENT.md "품질 기준선"

    python3 tools/quality_baseline.py            # 표로 출력
    python3 tools/quality_baseline.py --tsv      # 원장에 붙일 한 줄
"""
import argparse
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Mosco"

# 이 폴더들만 센다. DerivedData·빌드 산출물은 제외.
AREAS = {
    "App(조립)": SRC / "App",           # Features·Common을 뺀 나머지 = RootTabView 등
    "App/Features": SRC / "App" / "Features",
    "App/Common": SRC / "App" / "Common",
    "Shared": SRC / "Shared",
    "MoscoWidget": SRC / "MoscoWidget",
    "MoscoTests": SRC / "MoscoTests",
}

# 뷰 안에 있으면 곤란한 것들. 완벽한 판정은 불가능하고, 추세를 보는 용도다.
LOGIC_IN_VIEW = {
    "날짜 계산": re.compile(r"Calendar\.current|dateComponents\(|date\(bySetting|startOfDay"),
    "정렬·필터": re.compile(r"\.sorted\s*[({]|\.filter\s*[({]|\.first\s*\{"),
    "정규식·문자열 수술": re.compile(r"NSRegularExpression|removeSubrange|replacingOccurrences|components\(separatedBy"),
    "저장소 접근": re.compile(r"modelContext\.(insert|delete|save)|FetchDescriptor"),
}

HARDCODED_FONT = re.compile(r"\.font\(\.system\(size:")
# Metrics.* 가 아닌 숫자 여백
HARDCODED_PADDING = re.compile(r"\.padding\((?:\.\w+,\s*)?\d")
SINGLETON = re.compile(r"static\s+(?:let|var)\s+shared\b")
COND_COMPILE = re.compile(r"#if\s+(?:!)?targetEnvironment|#if\s+canImport")
TEMP_MARK = re.compile(r"//\s*TEMP:")
TEST_CASE = re.compile(r"@Test\b|func\s+test[A-Z_]")
# 타입 선언. 레이어 사이 참조를 찾을 때 쓴다.
DECL = re.compile(r"^\s*(?:public |private |internal |final |@MainActor |nonisolated )*"
                  r"(?:struct|class|enum|protocol|actor)\s+([A-Z][A-Za-z0-9]{3,})", re.M)


def swift_files(base: Path, top_only: bool = False):
    if not base.exists():
        return []
    pattern = base.glob("*.swift") if top_only else base.rglob("*.swift")
    return sorted(pattern)


LINE_COMMENT = re.compile(r"//.*$", re.M)
BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.S)
STRING_LITERAL = re.compile(r'"(?:[^"\\\n]|\\.)*"')


def code_only(text: str) -> str:
    """주석과 문자열을 걷어낸다.

    주석에서 다른 화면 이름을 언급하는 것은 의존이 아니다 — 오히려 이 저장소는
    "왜 이렇게 했는지"를 주석에 적는 습관이 있어서, 안 걷으면 위반이 아닌 것이
    잔뜩 잡히고 그러면 이 검사를 아무도 안 믿게 된다.
    """
    text = BLOCK_COMMENT.sub(" ", text)
    text = LINE_COMMENT.sub(" ", text)
    return STRING_LITERAL.sub('""', text)


def declared_types(files) -> dict:
    """파일마다 그 안에서 선언한 타입 이름들."""
    out = {}
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        out[path] = set(DECL.findall(text))
    return out


def layer_violations():
    """레이어 사이 의존 방향을 검사한다.

    도메인(Shared) ← 어댑터(App/Common) ← 프레젠테이션(App/Features).
    안쪽으로만 향해야 한다. 컴파일러가 잡아주는 방향(Shared → App)은 빌드가
    이미 막으므로, **같은 타깃 안이라 컴파일러가 못 잡는 둘**만 본다.
    """
    features_root = AREAS["App/Features"]
    common_root = AREAS["App/Common"]
    feature_dirs = sorted(d for d in features_root.glob("*") if d.is_dir())

    # 화면별로 자기가 선언한 타입
    owned = {}
    for d in feature_dirs:
        types = set()
        for _, names in declared_types(swift_files(d)).items():
            types |= names
        owned[d.name] = types

    violations = []

    # 1) 화면 → 다른 화면
    for d in feature_dirs:
        others = {name: types for name, types in owned.items() if name != d.name}
        for path in swift_files(d):
            text = code_only(path.read_text(encoding="utf-8", errors="replace"))
            mine = owned[d.name]
            for other_name, types in others.items():
                for t in sorted(types - mine):
                    if re.search(rf"\b{t}\b", text):
                        violations.append(("화면→화면", f"{d.name} → {other_name}", t,
                                           str(path.relative_to(ROOT))))
                        break

    # 2) 어댑터 → 화면
    all_feature_types = set().union(*owned.values()) if owned else set()
    common_types = set()
    for _, names in declared_types(swift_files(common_root)).items():
        common_types |= names
    for path in swift_files(common_root):
        text = code_only(path.read_text(encoding="utf-8", errors="replace"))
        for t in sorted(all_feature_types - common_types):
            if re.search(rf"\b{t}\b", text):
                violations.append(("어댑터→화면", "App/Common → Features", t,
                                   str(path.relative_to(ROOT))))
                break

    return violations


def is_view_file(text: str) -> bool:
    return ": View" in text or ": ViewModifier" in text


# 관례 밖으로 나가는 것들. 새로 들이면 사람이 봐야 한다.
NEW_CONCEPTS = [
    (re.compile(r"static\s+(?:let|var)\s+shared\b"), "새 싱글턴",
     "정당한 예외는 둘뿐이다 (CONVENTIONS 2절)"),
    (re.compile(r"#if\s+targetEnvironment"), "새 플랫폼 분기",
     "한쪽에서만 도는 코드는 다른 쪽에서 안 도는 걸 아무도 안 알려준다"),
    (re.compile(r"^\+\s*(?:public |private |internal )?protocol\s+"), "새 프로토콜",
     "추상화를 하나 늘리는 것이다"),
    (re.compile(r"UserDefaults\.standard"), "전역 저장소 직접 접근",
     "주입받게 할 수 있는지 본다"),
    (re.compile(r"\.font\(\.system\(size:"), "폰트 크기 하드코딩",
     "토큰을 쓰거나 토큰에 추가하고 말한다 (R6)"),
    (re.compile(r"//\s*TEMP:"), "임시 코드",
     "커밋 전에 걷는다 (R11)"),
    (re.compile(r"try!|as!|\bfatalError\("), "실패를 감추는 표현",
     "왜 여기서는 죽어도 되는지 근거가 필요하다"),
]


def report_deviation(base: str) -> int:
    """`base` 이후 추가된 줄에서 관례 밖 요소를 찾는다.

    이 저장소에는 규범이 있다(docs/architecture/CONVENTIONS.md). 기존 패턴을 그대로
    따른 코드는 기계가 판정할 수 있고, **관례 밖으로 나간 코드만 사람이 보면 된다.**
    그 판단을 돕는 것이 이 모드다 — 무엇이 새로 들어왔는지만 알려준다.

    판정은 하지 않는다. 새 개념이 필요한 변경도 당연히 있다. 다만 그런 변경은
    PR에서 🔴로 두고 근거를 적는다 (docs/review-criteria.md).
    """
    diff = subprocess.run(
        ["git", "diff", f"{base}...HEAD", "--", "*.swift"],
        cwd=ROOT, capture_output=True, text=True).stdout

    added = [line for line in diff.splitlines() if line.startswith("+") and not line.startswith("+++")]
    if not diff.strip():
        print(f"\n  {base} 이후 Swift 변경이 없습니다.\n")
        return 0

    hits = []
    for line in added:
        for pattern, label, why in NEW_CONCEPTS:
            if pattern.search(line):
                hits.append((label, why, line[1:].strip()[:70]))

    new_files = subprocess.run(
        ["git", "diff", f"{base}...HEAD", "--name-only", "--diff-filter=A", "--", "*.swift"],
        cwd=ROOT, capture_output=True, text=True).stdout.split()

    print(f"\n  관례에서 벗어난 것  ({base} 이후)\n")
    if new_files:
        print("  ─ 새 파일 ────────────────────────────")
        for f in new_files:
            print(f"    {f}")
        print()

    if hits:
        print("  ─ 새로 들인 개념 ─────────────────────")
        seen = set()
        for label, why, snippet in hits:
            if label not in seen:
                print(f"\n  ⚠️  {label} — {why}")
                seen.add(label)
            print(f"      {snippet}")
        print("\n  이런 것이 있으면 그 파일은 🔴다 (docs/review-criteria.md).")
    else:
        print("  ✅ 새로 들인 개념 없음 — 기존 관례 안에서 쓴 변경이다")
    print()
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", action="store_true", help="원장에 붙일 한 줄만 출력")
    ap.add_argument("--since", metavar="REF",
                    help="그 ref 이후에 새로 들인 '관례 밖' 요소를 찾는다 (예: main)")
    args = ap.parse_args()

    if args.since:
        return report_deviation(args.since)

    stats = Counter()
    per_area = {}
    big_files = []
    logic_hits = Counter()

    for name, base in AREAS.items():
        files = swift_files(base, top_only=(name == "App(조립)"))
        lines = 0
        for path in files:
            text = path.read_text(encoding="utf-8", errors="replace")
            n = text.count("\n") + 1
            lines += n
            if n >= 500:
                big_files.append((n, str(path.relative_to(ROOT))))

            stats["fonts"] += len(HARDCODED_FONT.findall(text))
            stats["paddings"] += len(HARDCODED_PADDING.findall(text))
            stats["singletons"] += len(SINGLETON.findall(text))
            stats["cond"] += len(COND_COMPILE.findall(text))
            stats["temp"] += len(TEMP_MARK.findall(text))
            if name == "MoscoTests":
                stats["tests"] += len(TEST_CASE.findall(text))

            # 뷰 파일 안의 비자명 로직
            if name.startswith("App/") and is_view_file(text):
                for label, pattern in LOGIC_IN_VIEW.items():
                    hits = len(pattern.findall(text))
                    if hits:
                        logic_hits[label] += hits

        per_area[name] = (len(files), lines)
        stats["files"] += len(files)
        stats["lines"] += lines

    if args.tsv:
        head = subprocess.run(
            ["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
            capture_output=True, text=True).stdout.strip()
        print("\t".join(str(x) for x in [
            head, stats["files"], stats["lines"], stats["tests"],
            sum(logic_hits.values()), len(big_files), stats["singletons"],
            stats["cond"], stats["fonts"], stats["paddings"], stats["temp"],
        ]))
        return 0

    print(f"\n  코드 품질 기준선   {stats['files']}파일 · {stats['lines']:,}줄\n")
    print("  ─ 영역별 ─────────────────────────────")
    for name, (count, lines) in per_area.items():
        print(f"  {name:<16} {count:>4}파일 {lines:>7,}줄")

    print("\n  ─ 테스트 ─────────────────────────────")
    print(f"  테스트 수                {stats['tests']:>6}")
    feature_tests = 0  # Features를 대상으로 하는 테스트는 구조상 존재할 수 없다
    print(f"  Features 대상 테스트     {feature_tests:>6}   (테스트 타깃이 Shared/만 컴파일한다)")

    print("\n  ─ 뷰 안의 비자명 로직 ────────────────")
    for label, count in logic_hits.most_common():
        print(f"  {label:<20} {count:>6}")
    print(f"  {'합계':<20} {sum(logic_hits.values()):>6}   (낮을수록 좋음)")

    print("\n  ─ 덩치 ───────────────────────────────")
    print(f"  500줄 넘는 파일          {len(big_files):>6}")
    for n, path in sorted(big_files, reverse=True):
        print(f"      {n:>5}줄  {path}")

    print("\n  ─ 결합·우회 ──────────────────────────")
    print(f"  싱글턴(static shared)    {stats['singletons']:>6}")
    print(f"  조건부 컴파일 분기        {stats['cond']:>6}")
    print(f"  폰트 크기 하드코딩        {stats['fonts']:>6}   (토큰 우회)")
    print(f"  숫자 여백                {stats['paddings']:>6}   (Metrics 우회 가능성)")

    print("\n  ─ 레이어 의존 방향 ───────────────────")
    print("  도메인(Shared) ← 어댑터(App/Common) ← 프레젠테이션(App/Features)")
    violations = layer_violations()
    if violations:
        for kind, edge, symbol, path in violations:
            print(f"  ⚠️  {kind:<10} {edge:<28} {symbol}  ({path})")
    else:
        print("  ✅ 위반 없음")
    print("  (Shared → App 방향은 위젯·테스트 빌드가 이미 막는다)")

    print("\n  ─ 임시 코드 ──────────────────────────")
    mark = "✅" if stats["temp"] == 0 else "⚠️"
    print(f"  {mark} // TEMP: 표식        {stats['temp']:>6}   (0이어야 한다)")

    print("\n  세지 못하는 것: 같은 로직의 복사본, Feature 간 순환 의존,")
    print("  추상화의 적정성. 이건 사람이 본다 (docs/review-criteria.md).\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
