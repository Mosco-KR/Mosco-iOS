#!/usr/bin/env python3
"""버전별 AI 사용 지표를 뽑는다.

이 스크립트의 존재 이유는 정확성이 아니라 **재현성**이다. 아래 정의는 노이즈를
품고 있다 — 사양 설명에 들어간 "안 되면"이 재지시로 잡히기도 한다. 그래도 괜찮다.
정의가 버전마다 그대로이기만 하면 노이즈도 같은 크기로 들어가므로 추세는 살아 있다.

**정의를 고치면 그 순간 이전 버전과 비교가 끊긴다.** 고쳐야 할 이유가 생기면
SCHEMA를 올리고, 이전 버전들을 새 정의로 다시 돌려 metrics.tsv를 통째로 재생성한다.
그렇게 하지 않으려면 정의를 건드리지 않는다.

    사용법:
      python3 tools/harness_report.py --version 1.1.0
      python3 tools/harness_report.py --version 1.2.0 --to HEAD
      python3 tools/harness_report.py --version 1.1.0 --append

    출력: 사람이 읽는 요약 + docs/harness/metrics.tsv 한 줄
"""

import argparse
import datetime as dt
import json
import os
import pathlib
import re
import statistics
import subprocess
import sys
from collections import Counter, defaultdict

# 정의를 바꾸면 이 번호를 올리고 전체 버전을 다시 돌린다.
SCHEMA = "1"

REPO = pathlib.Path(__file__).resolve().parent.parent
LEDGER = REPO / "docs" / "harness" / "metrics.tsv"

# ── 얼려둔 정의 ────────────────────────────────────────────────────────────
# 여기 아래를 수정하는 것은 스키마 변경이다. SCHEMA를 올려야 한다.

# M1 재지시 — 이미 나온 산출물을 되돌리거나, 여전히 안 된다고 알리는 발화.
RE_REWORK = re.compile(
    r"아직|여전히"
    r"|안\s?되|안\s?돼|안됨|안\s?함"
    r"|동작을?\s?안|동작이\s?안|작동을?\s?안"
    r"|해결이\s?안|수정이\s?안|적용이\s?안|반영이\s?안"
    r"|^\s*(아니|아냐|ㄴㄴ)"
    r"|아니아니"
    r"|다시\s?해|다시\s?시도"
    r"|안\s?보이|안보이|안\s?나와|안나와|안\s?잡|안잡|안\s?눌|고장"
    r"|버그",
    re.M,
)

# M4 감각 피드백 — 측정이 아니라 느낌으로 품질을 판정하는 발화.
RE_SENSORY = re.compile(
    r"구려|어색|아쉬|이상해|촌스|별로|불만족|부자연"
    r"|매끄|버벅|프레임\s?드랍|퀄리티|예쁘|이뻐|못생|허전|답답"
)

# M2 배치 — 한 프롬프트에 독립된 요청이 여러 개 들어간 것.
RE_LIST_ITEM = re.compile(r"^\s*(?:\d+[.)]|[-*•])\s+", re.M)

# M5 주제 — 스레드 길이를 재기 위한 고정 주제 사전. 한 프롬프트가 여러 주제에
# 걸릴 수 있다(의도된 것이다 — 배치 프롬프트가 그렇다).
TOPICS = {
    "캘린더 성능": r"프레임|버벅|성능|드랍|매끄|최적화",
    "캘린더 애니메이션": r"압축|확장|애니메이션|캐러샐|캐러셀",
    "셀·태그 표기": r"리퀴드|글라스|샐|셀\s|태그|칩|블록",
    "색·시각 톤": r"색상|색깔|팔레트|테마\s?컬러|톤|투명도|디자인",
    "카피라이팅": r"카피|라이팅|워딩|문구|텍스트들|제목|이름",
    "튜토리얼": r"튜토",
    "위젯": r"위젯",
    "라이브 액티비티": r"라이브\s?엑|라이브\s?액|다이나믹\s?아일랜드",
    "애널리틱스": r"아날리틱|애널리틱|로깅|Firebase|firebase|Analytics|이벤트",
    "카테고리 분류": r"CoreML|CoreMl|임베딩|자동\s?분류|카테고라이징|centroid",
    "알림": r"알림|푸시|notification",
    "동기화·저장": r"iCloud|아이클라우드|동기화|영속성|CoreData|SwiftData",
    "심사·스토어": r"심사|앱스토어|App\sStore|스토어|리뷰\s?유도|제출",
}

# M7 되돌림 — 지웠다가 다시 넣은 흔적.
RE_REMOVE = re.compile(r"제거|삭제|걷어내|없애|빼기|해제")
RE_READD = re.compile(r"다시|되살|복구|재도입|추가|붙이기")

BUILD_TOOL = "mcp__Claude_Code_iOS_Simulator__build"
SIM_TOOL = "mcp__Claude_Code_iOS_Simulator__control"

# 규범 문서 — M8 드리프트 검사 대상.
CANON_DOCS = [
    "Mosco/App/Common/DesignSystem/README.md",
    "docs/TRAPS.md",
    "CLAUDE.md",
]

# ── 유틸 ──────────────────────────────────────────────────────────────────


def git(*args):
    return subprocess.run(
        ["git", "-C", str(REPO), *args], capture_output=True, text=True
    ).stdout.strip()


def transcript_dir():
    slug = str(REPO).replace("/", "-")
    return pathlib.Path.home() / ".claude" / "projects" / slug


def parse_iso(s):
    if not s:
        return None
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00"))


def tag_time(tag):
    out = git("for-each-ref", "--format=%(creatordate:iso-strict)", f"refs/tags/{tag}")
    return parse_iso(out) if out else None


def resolve_window(version, to_ref):
    """이 버전이 차지하는 시간 구간과 커밋 범위를 정한다."""
    tags = [
        l.split()[0]
        for l in git(
            "for-each-ref", "--sort=creatordate", "--format=%(refname:short)", "refs/tags"
        ).splitlines()
    ]
    tag = f"V{version}"

    if tag in tags:
        end = tag_time(tag)
        idx = tags.index(tag)
        prev = tags[idx - 1] if idx > 0 else None
        rng = f"{prev}..{tag}" if prev else tag
    else:
        # 아직 태그를 안 찍은 진행 중 버전.
        end = dt.datetime.now(dt.timezone.utc)
        prev = tags[-1] if tags else None
        rng = f"{prev}..{to_ref}" if prev else to_ref

    if prev:
        start = tag_time(prev)
    else:
        # 최초 버전 — 저장소 첫 커밋부터. 그 앞 세션까지 포함해야 기획 단계가 잡힌다.
        first = git("log", "--reverse", "--pretty=%ad", "--date=iso-strict").splitlines()
        start = parse_iso(first[0]) - dt.timedelta(days=1) if first else None
    return start, end, rng, prev


# ── 트랜스크립트 ──────────────────────────────────────────────────────────


def read_sessions(start, end):
    """구간 안의 사람 프롬프트와 도구 사용을 시간순으로 모은다."""
    prompts, builds, sims, edits = [], [], 0, 0
    tool_names = {}

    d = transcript_dir()
    if not d.is_dir():
        sys.exit(f"세션 기록을 찾을 수 없습니다: {d}")

    rows = []
    for fp in sorted(d.glob("*.jsonl")):
        with open(fp, errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                ts = parse_iso(rec.get("timestamp"))
                if ts is None:
                    continue
                if start and ts <= start:
                    continue
                if end and ts > end:
                    continue
                rows.append((ts, rec))
    rows.sort(key=lambda r: r[0])

    for ts, rec in rows:
        kind = rec.get("type")
        msg = rec.get("message") or {}

        if kind == "user" and (rec.get("origin") or {}).get("kind") == "human":
            c = msg.get("content")
            if isinstance(c, list):
                c = " ".join(
                    x.get("text", "") for x in c if isinstance(x, dict)
                )
            if isinstance(c, str) and c.strip():
                prompts.append((ts, c.strip()))

        elif kind == "assistant":
            for b in msg.get("content") or []:
                if not isinstance(b, dict) or b.get("type") != "tool_use":
                    continue
                name = b.get("name")
                tool_names[b.get("id")] = name
                inp = b.get("input") or {}
                if name in ("Edit", "Write"):
                    edits += 1
                elif name == SIM_TOOL:
                    sims += 1
                elif name == BUILD_TOOL:
                    builds.append(("mcp", b.get("id")))
                elif name == "Bash":
                    cmd = inp.get("command", "")
                    if "xcodebuild" in cmd and " build" in cmd:
                        builds.append(("bash", b.get("id")))

        elif kind == "user" and rec.get("toolUseResult") is not None:
            c = msg.get("content")
            if isinstance(c, list):
                for b in c:
                    if isinstance(b, dict) and b.get("type") == "tool_result":
                        tid = b.get("tool_use_id")
                        rows_txt = json.dumps(b.get("content"))[:8000]
                        for i, entry in enumerate(builds):
                            if entry[1] == tid and len(entry) == 2:
                                builds[i] = (entry[0], entry[1], rows_txt)

    return prompts, builds, sims, edits


def screenshot_count(start, end):
    d = transcript_dir()
    n = 0
    for fp in sorted(d.glob("*.jsonl")):
        with open(fp, errors="replace") as f:
            for line in f:
                try:
                    rec = json.loads(line)
                except ValueError:
                    continue
                if rec.get("type") != "assistant":
                    continue
                ts = parse_iso(rec.get("timestamp"))
                if ts is None or (start and ts <= start) or (end and ts > end):
                    continue
                for b in (rec.get("message") or {}).get("content") or []:
                    if (
                        isinstance(b, dict)
                        and b.get("type") == "tool_use"
                        and b.get("name") == SIM_TOOL
                        and (b.get("input") or {}).get("action") == "screenshot"
                    ):
                        n += 1
    return n


# ── 지표 ──────────────────────────────────────────────────────────────────


def is_batch(text):
    if len(RE_LIST_ITEM.findall(text)) >= 2:
        return True
    lines = [l for l in text.splitlines() if l.strip()]
    return len(lines) >= 3


def compute(prompts, builds, sims, edits, shots, rng):
    n = len(prompts)
    out = {"prompts": n}
    if n == 0:
        return out

    texts = [t for _, t in prompts]
    rework = [bool(RE_REWORK.search(t)) for t in texts]
    batch = [is_batch(t) for t in texts]

    # M1 재지시율
    out["m1_rework_rate"] = round(100 * sum(rework) / n, 1)

    # M2 배치 유발 재지시 배수 — 배치 프롬프트 **다음** 프롬프트가 재지시일 확률을
    # 단일 프롬프트 다음의 확률로 나눈 값. 1.0이면 배치가 재작업을 늘리지 않는다는 뜻.
    after_batch = [rework[i + 1] for i in range(n - 1) if batch[i]]
    after_single = [rework[i + 1] for i in range(n - 1) if not batch[i]]
    pb = sum(after_batch) / len(after_batch) if after_batch else 0.0
    ps = sum(after_single) / len(after_single) if after_single else 0.0
    out["m2_batch_penalty"] = round(pb / ps, 2) if ps else None
    out["batch_rate"] = round(100 * sum(batch) / n, 1)

    # M3 빌드 실패율
    det = fail = 0
    for b in builds:
        if len(b) < 3:
            continue
        txt = b[2]
        if "BUILD SUCCEEDED" in txt or '"success": true' in txt:
            det += 1
        elif "BUILD FAILED" in txt or "error:" in txt:
            det += 1
            fail += 1
    out["builds"] = len(builds)
    out["m3_build_fail_rate"] = round(100 * fail / det, 1) if det else None

    # M4 감각 피드백률
    out["m4_sensory_rate"] = round(100 * sum(RE_SENSORY.search(t) is not None for t in texts) / n, 1)

    # M5 최다 주제 집중도 — 한 주제가 전체 지시의 몇 %를 먹었는가. 개수가 아니라
    # 비율이어야 버전 크기가 달라도 비교된다. 높으면 한 문제에 갇혀 있었다는 뜻.
    counts = {
        name: sum(1 for t in texts if re.search(pat, t))
        for name, pat in TOPICS.items()
    }
    counts = {k: v for k, v in counts.items() if v}
    if counts:
        top = max(counts.items(), key=lambda kv: kv[1])
        out["m5_top_topic_share"] = round(100 * top[1] / n, 1)
        out["m5_top_topic"] = top[0]
    out["_topics"] = counts

    # M9 검증 밀도 — 프롬프트 100개당 스크린샷 + 빌드
    out["m9_verify_density"] = round(100 * (shots + len(builds)) / n, 1)
    out["screenshots"] = shots
    out["sim_actions"] = sims
    out["edits"] = edits

    # 같은 프롬프트 재전송
    dup = Counter(texts)
    out["resends"] = sum(c - 1 for c in dup.values() if c > 1)

    return out


def git_metrics(rng):
    out = {}
    subjects = [s for s in git("log", "--pretty=%s", rng).splitlines() if s]
    out["commits"] = len(subjects)

    types = Counter()
    for s in subjects:
        m = re.match(r"^(\w+)(\(|:)", s)
        if m:
            types[m.group(1)] += 1
    out["_types"] = dict(types)
    feat, fix = types.get("feat", 0), types.get("fix", 0)
    out["m6_fix_per_feat"] = round(fix / feat, 2) if feat else None

    # M7 되돌림 — 같은 scope에서 제거 → 재도입
    scoped = []
    for s in subjects:
        m = re.match(r"^\w+\(([^)]+)\):\s*(.+)$", s)
        if m:
            scoped.append((m.group(1), m.group(2)))
    scoped.reverse()  # 시간순
    seen_removed, pairs = {}, []
    for scope, body in scoped:
        if RE_REMOVE.search(body):
            seen_removed[scope] = body
        elif scope in seen_removed and RE_READD.search(body):
            pairs.append((scope, seen_removed.pop(scope), body))
    out["m7_reversals"] = len(pairs)
    out["_reversal_pairs"] = pairs

    loc = git("ls-files", "*.swift").splitlines()
    total = 0
    for f in loc:
        p = REPO / f
        if p.exists():
            total += sum(1 for _ in p.open(errors="replace"))
    out["swift_loc"] = total
    out["swift_files"] = len(loc)
    return out


# M10 회귀 테스트 — 빌드 없이 정적으로 센다. 테스트를 "돌렸는가"가 아니라
# "남겼는가"를 재는 값이다. 고친 버그마다 테스트가 하나씩 늘어야 한다.
RE_TEST_FN = re.compile(r"^\s*(?:@Test\b|func\s+test[A-Z_])", re.M)


def test_count(ref):
    listing = subprocess.run(
        ["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", ref],
        capture_output=True, text=True,
    ).stdout.splitlines()
    n = 0
    for f in listing:
        if not f.endswith(".swift"):
            continue
        low = f.lower()
        if "test" not in low:
            continue
        body = subprocess.run(
            ["git", "-C", str(REPO), "show", f"{ref}:{f}"],
            capture_output=True, text=True,
        ).stdout
        n += len(RE_TEST_FN.findall(body))
    return n


# 제거를 **기록한** 문장은 드리프트가 아니다. "PriorityTag는 없앴다"는 정확한 문서다.
RE_DOCUMENTED_REMOVAL = re.compile(r"없앴|없앤|제거|삭제|지웠|폐기|걷어냈|쓰지\s?않는다|잔재")


def canon_drift(ref):
    """규범 문서가 실존하지 않는 파일·심볼을 가리키는 수.

    문서가 코드보다 뒤처지면 규범을 신뢰할 수 없고, 신뢰할 수 없는 규범은 규칙으로
    작동하지 않는다. 그래서 이건 문서 위생이 아니라 하네스 건강 지표다.

    해당 버전의 트리에서 재므로 과거 버전 행도 정확하다.
    """
    def at_ref(path):
        out = subprocess.run(
            ["git", "-C", str(REPO), "show", f"{ref}:{path}"],
            capture_output=True, text=True,
        )
        return out.stdout if out.returncode == 0 else None

    listing = subprocess.run(
        ["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", ref],
        capture_output=True, text=True,
    ).stdout.splitlines()
    swift_paths = [f for f in listing if f.endswith(".swift")]
    swift_files = {pathlib.Path(f).name for f in swift_paths}
    all_src = "".join(at_ref(f) or "" for f in swift_paths)

    misses = []
    for doc in CANON_DOCS:
        text = at_ref(doc)
        if text is None:
            continue
        for line in text.splitlines():
            if RE_DOCUMENTED_REMOVAL.search(line):
                continue
            for r in re.findall(r"`([A-Za-z_][A-Za-z0-9_+]*\.swift)`", line):
                if r not in swift_files:
                    misses.append(f"{doc} → {r}")
            for r in re.findall(r"`([A-Z][A-Za-z0-9_]{3,})`", line):
                if r.endswith(".swift"):
                    continue
                if not re.search(rf"\b{re.escape(r)}\b", all_src):
                    misses.append(f"{doc} → {r}")
    return sorted(set(misses))


# ── 출력 ──────────────────────────────────────────────────────────────────

COLUMNS = [
    "schema", "version", "window_start", "window_end", "days",
    "prompts", "commits", "swift_loc",
    "m1_rework_rate", "m2_batch_penalty", "m3_build_fail_rate",
    "m4_sensory_rate", "m5_top_topic_share", "m6_fix_per_feat",
    "m7_reversals", "m8_canon_drift", "m9_verify_density", "m10_tests",
    "batch_rate", "resends", "builds", "screenshots", "sim_actions", "edits",
]


def fmt(v):
    return "" if v is None else str(v)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="예: 1.1.0")
    ap.add_argument("--to", default="HEAD", help="태그가 없는 진행 중 버전의 끝 ref")
    ap.add_argument("--append", action="store_true", help="metrics.tsv에 한 줄 덧붙인다")
    args = ap.parse_args()

    start, end, rng, prev = resolve_window(args.version, args.to)
    prompts, builds, sims, edits = read_sessions(start, end)
    shots = screenshot_count(start, end)

    m = compute(prompts, builds, sims, edits, shots, rng)
    g = git_metrics(rng)
    ref = f"V{args.version}" if tag_time(f"V{args.version}") else args.to
    drift = canon_drift(ref)
    tests = test_count(ref)

    days = (end - (start or end)).days if start else None
    row = {
        "schema": SCHEMA,
        "version": args.version,
        "window_start": start.date().isoformat() if start else "",
        "window_end": end.date().isoformat(),
        "days": days if days else "",
        "m8_canon_drift": len(drift),
        "m10_tests": tests,
        **{k: v for k, v in m.items() if not k.startswith("_")},
        **{k: v for k, v in g.items() if not k.startswith("_")},
    }

    print(f"\n  Mosco 하네스 지표 — v{args.version}   (schema {SCHEMA})")
    print(f"  구간 {row['window_start'] or '(최초)'} → {row['window_end']}"
          f"   커밋 범위 {rng}\n")
    print(f"  규모      프롬프트 {m.get('prompts', 0)} · 커밋 {g['commits']}"
          f" · Swift {g['swift_loc']}줄")
    print(f"  배치      {m.get('batch_rate')}% 가 여러 항목 · 동일 재전송 {m.get('resends')}건")
    print()
    if m.get("prompts", 0) < 50:
        print(f"  ⚠ 프롬프트가 {m['prompts']}개뿐입니다. 아래 비율은 흔들림이 큽니다 —")
        print("    한 버전만 보고 규칙을 폐기하지 말고 두 버전 연속 같은 방향일 때 판단하세요.\n")

    print("  ─ 채점 지표 ────────────────────────────────────")
    print(f"  M1 재지시율            {fmt(m.get('m1_rework_rate')):>7}%   (낮을수록 좋음)")
    print(f"  M2 배치 유발 배수      {fmt(m.get('m2_batch_penalty')):>7}    (1.0 = 배치가 무해)")
    print(f"  M3 빌드 실패율         {fmt(m.get('m3_build_fail_rate')):>7}%")
    print(f"  M4 감각 피드백률       {fmt(m.get('m4_sensory_rate')):>7}%")
    print(f"  M5 최다 주제 집중도    {fmt(m.get('m5_top_topic_share')):>7}%   ({m.get('m5_top_topic','-')})")
    print(f"  M6 fix:feat            {fmt(g.get('m6_fix_per_feat')):>7}")
    print(f"  M7 되돌림 사이클       {fmt(g.get('m7_reversals')):>7}")
    print(f"  M8 규범 드리프트       {len(drift):>7}")
    print(f"  M9 검증 밀도           {fmt(m.get('m9_verify_density')):>7}    (프롬프트 100개당)")
    print(f"  M10 회귀 테스트        {tests:>7}    (높을수록 좋음)")
    print()

    if m.get("_topics"):
        print("  ─ 주제별 프롬프트 ──────────────────────────────")
        for k, v in sorted(m["_topics"].items(), key=lambda kv: -kv[1]):
            print(f"     {v:>4}  {k}")
        print()
    if g.get("_types"):
        print(f"  커밋 종류  {g['_types']}")
    if g.get("_reversal_pairs"):
        print("\n  되돌림:")
        for scope, a, b in g["_reversal_pairs"]:
            print(f"     ({scope}) {a}  →  {b}")
    if drift:
        print("\n  규범 드리프트:")
        for d in drift:
            print(f"     {d}")
    print()

    line = "\t".join(fmt(row.get(c)) for c in COLUMNS)
    if args.append:
        LEDGER.parent.mkdir(parents=True, exist_ok=True)
        new = not LEDGER.exists()
        with open(LEDGER, "a") as f:
            if new:
                f.write("\t".join(COLUMNS) + "\n")
            f.write(line + "\n")
        print(f"  → {LEDGER.relative_to(REPO)} 에 덧붙였습니다.\n")
    else:
        print("  TSV 한 줄 (--append 로 원장에 기록):")
        print("  " + line + "\n")


if __name__ == "__main__":
    main()
