# Mosco

한 줄 자연어 입력으로 할 일을 적고, 온디바이스 임베딩으로 카테고리를 자동 분류하는
iOS 캘린더/할 일 앱. 1인 개발. App Store 출시됨 (현재 1.2.0, 빌드 5).

## 무엇이 어디에 있나

```
Mosco/Mosco.xcodeproj        프로젝트 (스킴: App, MoscoWidget)
Mosco/App/Features/          Calendar / TodayTodo / Settings
Mosco/App/Common/
  DesignSystem/              토큰·컴포넌트 + README.md ← 디자인·문구 규범
  Tutorial/ ML/ Weather/ Sync/ Notifications/ Analytics/ Review/ Clipboard/
Mosco/MoscoWidget/           위젯 + 라이브 액티비티
Mosco/Shared/                앱·위젯 공용 (Analytics, CategoryColorPalette, LiveActivity)
Mosco/MoscoTests/            유닛 테스트 (Swift Testing). 폴더째 동기화된다

CONTRIBUTING.md              커밋·브랜치 규칙
RELEASING.md                 버전·태그·릴리스 노트
docs/TRAPS.md                플랫폼 함정. 해당 영역 건드리기 전에 읽는다
docs/CATEGORIZATION.md       카테고리 자동 분류가 어떻게 돌고 왜 Core ML을 버렸나
docs/BACKLOG.md              밀린 일
docs/architecture/           지금 구조(CURRENT.md)와 후보 패턴 비교(PATTERNS.md)
tools/artifact_check.sh      entitlements·plist·버전 일치 검사
tools/quality_baseline.py    코드 품질 기준선. 리팩터링 전후를 비교하려고 센다
tools/deadcode_audit.py      안 쓰이는 코드 훑기. periphery는 이 프로젝트에서 못 쓴다
tools/i18n_check.py          번역 빠진 문구 검사. 빌드로는 안 잡힌다
```

배포 타깃 iOS 17.0. 번들 ID `com.Mosco.App`.

CI는 PR마다 App·MoscoWidget 빌드와 테스트, 그리고 Mac Catalyst 빌드를 돌린다
(`.github/workflows/ci.yml`). Catalyst를 따로 빌드하는 것은 **iOS가 통과해도 맥은
깨질 수 있어서**다 — 라이브 액티비티가 조건부 컴파일로 가려져 있다.

## 빌드

```bash
xcodebuild -project Mosco/Mosco.xcodeproj -scheme App -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## 테스트

```bash
xcodebuild -project Mosco/Mosco.xcodeproj -scheme App -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

`MoscoTests`는 App 스킴에 물려 있어서 스킴 하나로 빌드와 테스트가 같이 돈다.
파일을 추가할 때 Xcode 프로젝트에 등록하지 않아도 된다 — `MoscoTests/` 폴더가
통째로 동기화된다.

**호스트 앱 없이 돈다.** 테스트 타깃은 `Shared/`를 직접 컴파일하고 App.app을 띄우지
않는다. 앱을 띄우면 CI에서 서명이 없어 저장소를 못 만들고 죽었고, 로컬에서도 매번
CloudKit 오류 로그를 뱉었다. 그래서 **테스트가 닿아야 하는 순수 로직은 `Shared/`에
둔다** — 화면 구조체 안에 두면 테스트를 쓸 수 없다.

UDID를 박아 쓰지 않는다 — 시뮬레이터는 지워지고 다시 생긴다. 이름으로 지정한다.

## 디자인 규범

UI·문구를 만지기 전에 `Mosco/App/Common/DesignSystem/README.md`를 읽는다.
그 문서는 스타일 가이드가 아니라 **되돌린 시도의 기록**이다 — 한 번 해보고 아니었던
것을 다시 제안하지 않기 위해 있다. 색·코너 반경·그림자는 토큰에서 가져다 쓰고,
새로 만들면 만들었다고 말한다. 문구는 `~해요`체 하나로 통일한다.

코드를 바꿔서 규범 문서가 틀리게 되면 그 자리에서 문서도 고친다.

## 일하는 방식

- 사용자는 `auto`/`acceptEdits`로 거의 항상 열어둔다. 편집을 일일이 승인하지 않으므로
  **되돌리기 쉬운 크기**로 나눠 진행한다.
- 피곤한 사람이 선택지 다섯 개를 비교하게 만들지 않는다. **근거 있는 결론 하나**를 준다.
- 조사를 지시하면 실제로 조사한다. 추측을 조사 결과처럼 쓰지 않는다.
- 커밋은 요청받을 때만. 대신 **쓸 수 있는 커밋 메시지 한 줄**을 답 끝에 제안한다.
- **모든 작업은 브랜치와 PR을 거친다.** `main`에 직접 커밋하지 않는다.
- **문서는 사람이 읽을 글로 쓴다.** 표와 목록으로만 채우지 말고, 왜 그런지를 문장으로
  적는다. 딱딱한 번역체를 쓰지 않는다. 읽는 사람이 피곤한 상태라고 가정한다.
