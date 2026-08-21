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


def swift_files(base: Path, top_only: bool = False):
    if not base.exists():
        return []
    pattern = base.glob("*.swift") if top_only else base.rglob("*.swift")
    return sorted(pattern)


def is_view_file(text: str) -> bool:
    return ": View" in text or ": ViewModifier" in text


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--tsv", action="store_true", help="원장에 붙일 한 줄만 출력")
    args = ap.parse_args()

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

    print("\n  ─ 임시 코드 ──────────────────────────")
    mark = "✅" if stats["temp"] == 0 else "⚠️"
    print(f"  {mark} // TEMP: 표식        {stats['temp']:>6}   (0이어야 한다)")

    print("\n  세지 못하는 것: 같은 로직의 복사본, Feature 간 순환 의존,")
    print("  추상화의 적정성. 이건 사람이 본다 (docs/review-criteria.md).\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
