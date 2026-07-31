# 우선순위 분류기 학습 데이터

`priority-training-data.csv` — 할 일 제목(text)을 4가지 우선순위(label)로 분류하는
Create ML Text Classifier용 데이터셋. 클래스별 85~97개, 총 354개.
사용자가 실제로 자주 치는 한두 단어짜리 짧은 입력("면접", "운동", "산책")도
클래스별로 포함되어 있다 — 긴 서술형만 있으면 짧은 입력에서 분류가 흔들린다.

| label | 의미 | 핵심 신호 |
|---|---|---|
| `must` | 마감·긴급·불이익이 있는 일 | 마감, 제출, 납부, 시험, 오늘까지 |
| `should` | 중요하지만 마감 압박은 없는 일 | 회의, 공부, 운동, 예약, 작성 |
| `could` | 여유 있을 때 하면 좋은 일 | 취미, 구경, 해보기, 언젠가 |
| `wont` | 안 하기로 했거나 보류한 일 + 절제 결심 | 보류, 취소, 끊기, 하지 말기, 금연/금주 |

## Create ML로 학습하기

1. Xcode → Open Developer Tool → **Create ML** → **Text Classification** 템플릿 선택
2. Training Data에 이 CSV를 드래그 (text 컬럼: `text`, label 컬럼: `label` 자동 인식)
3. Algorithm은 **Transfer Learning (BERT Embedding)** 먼저 시도 — 한국어 지원이 좋고
   적은 데이터로도 성능이 잘 나온다. 결과가 이상하면 Maximum Entropy로 폴백.
4. Validation은 Automatic로 두면 된다 (Create ML이 알아서 나눔).
5. Train 후 Output 탭에서 `PriorityClassifier.mlmodel`로 Export.

## 앱에 연결하기

1. `PriorityClassifier.mlmodel`을 Xcode 프로젝트(App 타깃)에 추가.
2. `PriorityClassifying` 프로토콜(Mosco/App/Features/Calendar/PriorityClassifying.swift)을
   구현하는 `CoreMLPriorityClassifier`를 만들어 `KeywordPriorityClassifier`를 교체.
   출력 label 문자열(`must`/`should`/`could`/`wont`)은 `Priority(rawValue:)`와 그대로 매칭된다.
3. 신뢰도(confidence)가 낮으면 nil을 리턴해 기존 기본값(.should)을 유지하는 걸 권장.

## 데이터 추가할 때

- 형식: `제목,label` 한 줄씩. 제목에 쉼표(,)는 넣지 말 것 (따옴표 이스케이프를 안 쓰는 중).
- 클래스 간 개수 균형을 유지할 것 (한쪽만 늘리면 그쪽으로 치우친다).
- 실제 앱에서 사용자가 고친 사례(자동 분류 → 수동 변경)를 여기에 추가하는 게 가장 효과적이다.
- 시간 표현("오후 7시 미팅")이 섞인 실제 입력 패턴도 일부 포함되어 있다 — 분류는
  시간 제거 전 원문으로 돌기 때문.
