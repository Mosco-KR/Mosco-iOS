# Mosco

[![CI](https://github.com/Mosco-KR/Mosco-iOS/actions/workflows/ci.yml/badge.svg)](https://github.com/Mosco-KR/Mosco-iOS/actions/workflows/ci.yml)

한 줄로 적으면 날짜·시각·카테고리가 알아서 붙는 캘린더 할 일 앱.
`7시 러닝`이라고 치면 오늘 19:00에 '운동' 카테고리로 들어간다.

iOS 17.0+ · SwiftUI + SwiftData · 1인 개발 · [App Store](https://apps.apple.com/app/id6796924940)

## 기능

**입력** — 자연어 한 줄 입력, 시각 자동 추출(`4시~7시`는 종료 시각까지),
온디바이스 임베딩으로 카테고리 자동 분류, 날짜·시각 모두 선택 사항

**캘린더** — 월 페이징, 여러 날에 걸친 할 일 블록, 반복 일정(요일·간격·매년),
공휴일·주말 표시, 날짜별 하루치 화면, 캘린더 나누기(개인/업무 등)

**할 일** — 지난 미완료 모아 보기와 오늘로 가져오기, 순서 직접 정하기(모든 화면 공유),
메모, 디데이, 복사·붙여넣기, 카테고리별 색과 알림

**바깥으로** — 홈 화면 위젯 3종, 잠금화면 위젯, 라이브 액티비티와 다이나믹 아일랜드,
iCloud 동기화, 날씨 표시(WeatherKit), 카테고리별 알림

## 빌드

```bash
xcodebuild -project Mosco/Mosco.xcodeproj -scheme App -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Firebase Analytics를 쓰지만 `GoogleService-Info.plist`는 저장소에 들어 있어서 따로
받을 것이 없다. 그 파일이 없어도 앱은 돌고 분석만 조용히 꺼진다
(`FirebaseAnalyticsSink.configure()`가 nil을 낸다).
시뮬레이터는 이름으로 지정한다 — UDID는 지워졌다 다시 생기면서 바뀐다.

검증 사다리는 빌드 → 테스트 → 사람 → 심사다. **`MoscoTests`(Swift Testing, 58건)와
CI가 앞의 두 칸을 맡는다** — PR마다 App·MoscoWidget 빌드와 테스트가 자동으로 돈다
([.github/workflows/ci.yml](.github/workflows/ci.yml)).

```bash
xcodebuild -project Mosco/Mosco.xcodeproj -scheme App -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

AI는 시뮬레이터를 직접 쓰지 않는다 — 로직은 테스트로 덮고, 화면 판정은 검증 카드로
사람에게 넘긴다. 예외는 PR에 넣을 화면을 찍을 때 하나뿐이다. 왜 그렇게 정했는지는
[규칙 원장의 폐기 절](docs/harness/rules.md)에 있다.

## 구조

```
Mosco/App/Features/     Calendar · TodayTodo · Settings
Mosco/App/Common/       DesignSystem · Tutorial · ML · Weather · Sync · Notifications
Mosco/MoscoWidget/      위젯 · 라이브 액티비티
Mosco/Shared/           앱과 위젯이 같이 쓰는 것
Mosco/MoscoTests/       유닛 테스트 (Swift Testing)
```

카테고리 자동 분류는 온디바이스 임베딩(`NLEmbedding` + 코사인 유사도)으로 돈다.
처음엔 Create ML로 학습시킨 분류기였는데 2026-07-30에 갈아탔다 — 어떻게 돌고
왜 갈아탔는지는 [docs/CATEGORIZATION.md](docs/CATEGORIZATION.md)에 있다.

## 문서

| 문서 | 무엇이 있나 |
|---|---|
| [CLAUDE.md](CLAUDE.md) | AI 작업 규칙 열 개 (R1~R10). 규칙마다 담당 지표가 있다 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 커밋·브랜치·PR·문서 갱신 규칙 |
| [RELEASING.md](RELEASING.md) | 버전 규칙, 태그, 릴리스 노트 쓰는 법 |
| [docs/TRAPS.md](docs/TRAPS.md) | 한 번씩 크게 시간을 쓴 플랫폼 함정 |
| [docs/BACKLOG.md](docs/BACKLOG.md) | 밀린 일. 버린 것과 버린 이유도 같이 |
| [docs/harness/](docs/harness/) | AI 작업 규칙이 효과 있었는지 채점하는 체계 |
| [DesignSystem/README.md](Mosco/App/Common/DesignSystem/README.md) | 디자인·문구 규범 = 되돌린 시도의 기록 |
| [PRIVACY.md](PRIVACY.md) | 개인정보 처리방침 |

### AI 사용 보고서

이 앱은 대부분 AI와 함께 만들었다. 그 과정을 버전마다 측정해서, 어떤 작업 규칙이
실제로 재작업을 줄였는지 채점하고 있다. **최종 목표는 같은 결론에 토큰을 덜 쓰고
도달하는 것**이고, 모든 판정은 프롬프트당 토큰(M12)으로 마무리한다.

- [v1.1.0 보고서](docs/harness/reports/v1.1.0.md) — 첫 보고서. 베이스라인과 규칙 R1~R10
- [지표 원장](docs/harness/metrics.tsv) · [규칙 원장](docs/harness/rules.md)
