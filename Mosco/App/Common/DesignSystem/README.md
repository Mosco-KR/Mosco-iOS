# Mosco Design System

Mosco의 시각 언어를 정리한 문서. 코드는 이 폴더(`Common/DesignSystem/`) 안에 있고, 전체를
한눈에 보려면 앱을 실행했을 때 뜨는 `StyleGuideView`를 참고.

## 원칙

- **절제된 톤.** 채도 높은 원색 대신 낮춘 톤을 쓴다. 색은 강조가 아니라 상태(우선순위) 구분용.
- **플랫이 기본, 글라스는 예외.** 카드/태그/본문은 전부 플랫(불투명) 표면으로 그린다. 리퀴드
  글라스(iOS 26 `glassEffect`)는 화면에 떠 있는 요소(플로팅 CTA 등) 한 곳에만 서지컬하게
  적용하고, 나머지에는 쓰지 않는다. (2026 Apple Design Award 수상작들의 공통 패턴 —
  Moonlitt 등도 글라스를 전체가 아니라 특정 요소에만 씀)
- **아이콘보다 텍스트.** 우선순위 구분에 이모지성 아이콘(예: `!!!`, 달 아이콘)을 쓰지 않는다.
  작은 점(dot) + 한글 라벨로 충분히 구분되게 한다.
- **기본 SF 폰트.** Rounded 디자인은 장난스러운 인상을 주므로 쓰지 않는다.

## 컬러 팔레트

| 이름 | 용도 | 값 |
|---|---|---|
| Must | 최우선 | `#D9484E` |
| Should | 해야 함 | `#C98A2E` |
| Could | 여유되면 | `#3182F6` |
| Won't | 나중에 | `#8B95A1` |
| Accent | 브랜드 액션(버튼 등), 우선순위 색과 분리 | `#3182F6` |

`background`/`surface`/`border`/`textPrimary`/`textSecondary`는 시스템 시맨틱 컬러를 그대로
써서 라이트/다크 모드가 자동 대응된다. (`Tokens/Palette.swift`)

## 타이포그래피

`Tokens/Typography.swift` — 전부 `.default` 디자인(SF Pro), Dynamic Type 텍스트 스타일 기반.

- `moscoLargeTitle` — 화면 타이틀
- `moscoTitle` — 섹션 타이틀
- `moscoHeadline` — 카드/섹션 제목, 버튼 레이블
- `moscoBody` — 본문
- `moscoCaption` — 태그, 보조 텍스트

## 컴포넌트

| 컴포넌트 | 역할 | 위치 |
|---|---|---|
| `TagChip` | 라벨 + 톤온톤 배경의 범용 캡슐 칩 (시간 표시 등) | `Components/TagChip.swift` |
| `PriorityTag` | MoSCoW 우선순위 칩 (점 + 라벨) | `Components/PriorityTag.swift` |
| `SurfaceCard` | 플랫 배경 + 헤어라인 보더 컨테이너 | `Components/SurfaceCard.swift` |
| `MoscoPrimaryButtonStyle` (`.moscoPrimary`) | 주요 액션 버튼. iOS 26+에서만 `glassEffect` 적용, 그 미만은 flat accent 배경 | `Components/MoscoButtonStyle.swift` |

`PriorityTag`가 쓰는 `DemoPriority`는 실제 도메인 모델(`MoscoModels`의 `Priority`)이 생기기
전까지의 임시 자리로, 나중에 도메인 enum에 색상 매핑만 이식하고 이 타입은 정리한다.

## 톤 참고

Toss/Apple류의 절제된 UI를 기준으로 삼는다 — 원색 대신 톤 다운된 색, 그라데이션 없는 플랫
버튼, 헤어라인 보더 카드. 화려하거나 장난스러운(스티커형) UI는 지양한다.
