# 스토어 페이지 문구

App Store Connect에 붙여 넣을 문구를 세 언어로 모아둔 곳이다. 2026년 9월 숫자를 보고 다시 썼다.

## 왜 다시 썼나

9월 한 달 동안 노출이 4,990번이었는데 제품 페이지까지 들어온 건 404번(8%)이었다. 페이지에
들어온 사람은 여섯 중 하나가 받았으니(65건), 새는 곳은 페이지 안이 아니라 **검색 결과에서
눌러보게 만드는 단계**다. 검색 결과에 보이는 건 아이콘, 이름, 부제, 그리고 미리보기 앞쪽
몇 장뿐이다.

그런데 예전 첫 장은 "한 줄이면 충분합니다"라는 말과 기울어진 달력이었다. 무엇이 한 줄인지는
둘째 장을 봐야 알 수 있었다. 이 앱이 다른 캘린더와 다른 점은 **"저녁 7시 약속"이라고 치면
시간과 분류가 알아서 붙는다**는 것 하나인데, 그게 첫 장에 없었다. 그래서 첫 장을 그
장면으로 바꾸고, 부제도 같은 말을 하게 맞췄다.

문구는 앱과 같은 `~해요`체로 쓴다. 예전 미리보기는 `~합니다`였다. 다만 **미리보기 문구는
설명하지 않고 보여준다** — "알아서 붙어요"처럼 기능을 해설하는 말투 대신, 화면이 이미 보여주는
결과를 짧게 받아 적는다. 세 장을 넘기는 2초 동안 읽히는 건 그 정도다.

## 이름 (30자 이내)

지금은 세 언어 모두 `Mosco - 할 일, 캘린더, 계획`이 나간다. 한국어를 읽지 못하는 사람에게는
글자가 깨진 것처럼 보이고, 검색에도 안 잡힌다. 언어마다 따로 넣는다.

- 한국어: `Mosco - 할 일, 캘린더, 계획`
- English: `Mosco - Calendar & To-Do`
- 日本語: `Mosco - カレンダーとToDo`

이름은 검색 가중치가 가장 높은 자리다. 그래서 앱 이름 뒤에 그 언어 사람이 실제로 검색창에
칠 낱말을 붙인다. 영어권은 `calendar`와 `to-do`, 일본은 `カレンダー`와 `ToDo`다.

## 부제 (30자 이내)

- 한국어: `한 줄 적으면 일정이 돼요`
- English: `One line becomes a plan`
- 日本語: `一行書けば予定になる`

## 미리보기 문구

다섯 장이고, 앞의 세 장이 검색 결과에 보인다. 그래서 앞 세 장만 봐도 "한 줄로 적는다 →
알아서 정리된다 → 달력에서 한눈에 본다"가 이어지게 했다. 넷째와 다섯째는 들어온 사람에게
매일 다시 열 이유(오늘 페이지, 위젯)를 보여준다. 9월에 남은 사람들은 위젯으로 한 사람당
열두 번씩 들어왔다.

| 장 | 화면 | 한국어 | English | 日本語 |
|---|---|---|---|---|
| 1 | 입력창에 한 줄을 친 순간, 시간 칩이 뜬 모습 | "저녁 약속 오후 7시"<br>한 줄이면 끝나요 | "Dinner 7pm"<br>One line. Done. | 「夕食 午後7時」<br>一行で完了 |
| 2 | 오늘 페이지(시간·카테고리가 붙은 카드들) | 시간과 분류는<br>알아서 들어가요 | Time and category,<br>already sorted | 時間も分類も<br>書いただけで |
| 3 | 달력 홈, 할 일 막대가 찬 한 달 | 한 달치가<br>한 화면에 | Your whole month<br>at a glance | ひと月分が<br>ひと画面に |
| 4 | 하루 시간표 | 오늘 하루가<br>시간순으로 | Your whole day,<br>hour by hour | 今日一日が<br>時間順に |
| 5 | 홈 화면 위젯 (아직 없음) | 열지 않아도<br>보여요 | Without opening<br>the app | 開かなくても<br>見える |

넷째 장은 처음엔 오늘 페이지로 잡았는데, 둘째 장과 같은 화면이 두 번 나오게 돼서 시간표로
바꿨다. 다섯째 장(위젯)은 홈 화면을 손으로 꾸며서 찍어야 해서 아직 없다.

### 다시 찍는 법

화면은 디버그 빌드의 실행 인자로 연다(`App/ScreenshotDemo.swift`). 예시 할 일이 그 언어로
채워지고, 안내와 권한 창은 뜨지 않는다. 손으로 탭할 것이 없다.

```bash
xcrun simctl status_bar 'iPhone 17 Pro' override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
```

```bash
xcrun simctl launch 'iPhone 17 Pro' com.Mosco.App -MoscoResetStore -MoscoScreenshot compose -AppleLanguages "(ja)" -AppleLocale ja_JP
```

```bash
xcrun simctl io 'iPhone 17 Pro' screenshot ja_compose.png
```

장면은 `compose`(한 줄을 친 달력 홈), `month`(달력 홈), `today`(오늘 페이지) 셋이다. 시간표는
`today`에 `-dayViewMode timeline`을 붙인다. 언어는 `ko`·`en`·`ja`.

찍은 화면에 문구와 배경을 입힌 것은 Canva 디자인 "Mosco App Store 미리보기 (한·영·일)"에
있다(2~13쪽이 한·영·일 네 장씩, 1쪽은 빈 페이지라 쓰지 않는다). 문구를 고치려면 거기서 고치고
PNG로 내보낸다. 내보낸 결과는 `store/screenshots/`에 **1242×2688**로 들어 있다.

**크기에 함정이 둘 있다.** 캔버스는 6.9형(1320×2868)으로 잡았는데 App Store Connect가 받아준
칸은 6.5형(1242×2688)이었다. 두 규격은 비율이 0.4% 달라서, 1242를 요구하면 Canva는 비율을
지키느라 1237로 내준다. 그래서 내보낸 뒤 좌우를 배경색으로 채워 정확히 맞춘다
(`tools/pad_screenshots.swift`). 또 **내보내기 URL은 순서가 아니라 경로의 `/0002-`를 보고
짝지어야 한다** — 순서대로 받으면 한 칸씩 밀린 채 이름이 붙는다. 한 번 당했다.

## 홍보 문구 (170자 이내)

- 한국어: `"내일 오후 3시 치과"처럼 한 줄만 적으면 시간과 분류가 알아서 붙어요. 달력을 열면 바로 적을 수 있어요.`
- English: `Type "Dentist 3pm" and the time and category fill themselves in. Open the calendar and start writing right away.`
- 日本語: `「歯医者 午後3時」と一行書くだけで、時間と分類が自動で入ります。カレンダーを開いてすぐ書けます。`

## 설명

### 한국어

```
할 일 앱에 적는 게 귀찮아서 안 적게 되나요?
Mosco는 한 줄만 적으면 돼요.

"저녁 7시 약속"이라고 치면 시간이 붙고,
"러닝"이라고 치면 운동 카테고리로 들어가요.
날짜 고르고, 시간 고르고, 분류 고르는 화면을 따로 열지 않아요.

■ 한 줄로 적어요
"오후 3시 회의", "4시~7시 스터디", "7pm 저녁"처럼 평소 말하듯 적으면 시간을 알아채요.

■ 분류는 알아서
카테고리를 만들어 두면, 적은 내용을 보고 맞는 곳에 넣어요.
이 계산은 전부 기기 안에서 해요. 적은 내용이 밖으로 나가지 않아요.

■ 달력에서 한눈에
한 달을 열면 할 일이 색 막대로 보여요. 며칠짜리 일정도 이어서 보여요.

■ 오늘만 모아서
달력에서 오늘을 누르면 오늘 할 일, 지난 할 일, 디데이가 한 페이지에 나와요.

■ 홈 화면 위젯
오늘 할 일, 주간 달력, 월 달력 위젯이 있어요. 앱을 안 열어도 보여요.

■ 그 밖에
반복 일정, 시작 전 알림, 잠금화면 남은 시간 표시, iCloud 동기화, 날씨, 테마 색.

계정을 만들 필요가 없어요.
```

### English

```
Do you skip writing things down because to-do apps take too many taps?
With Mosco, one line is enough.

Type "Dinner 7pm" and the time is set.
Type "Run" and it lands in your exercise category.
No separate screens for picking a date, a time, and a category.

■ Write one line
"Meeting 3pm", "Study 4pm to 7pm", "Lunch at noon" — write the way you'd say it and Mosco picks up the time.

■ Categories sort themselves
Create your categories once. Mosco reads what you wrote and files it in the right one.
All of this happens on your device. What you write never leaves it.

■ Your month at a glance
Open the calendar and your to-dos appear as colored bars. Multi-day plans stretch across the days.

■ Just today
Tap today on the calendar to see today's to-dos, overdue items, and D-Days on one page.

■ Home Screen widgets
Today's to-dos, a week calendar, and a month calendar. See them without opening the app.

■ Also
Repeating to-dos, reminders before start, Lock Screen countdown, iCloud sync, weather, theme color.

No account needed.
```

### 日本語

```
ToDoアプリは入力が面倒で、結局書かなくなっていませんか？
Moscoなら一行で十分です。

「夕食 午後7時」と書けば時間が入り、
「ランニング」と書けば運動のカテゴリに入ります。
日付、時間、分類を選ぶ画面を別々に開く必要はありません。

■ 一行で書く
「会議 午後3時」「勉強 14時〜17時」「19時 夕食」のように、普段の言い方で書くと時間を読み取ります。

■ 分類は自動
カテゴリを作っておけば、書いた内容を見て合うところに入れます。
この処理はすべて端末内で行われます。書いた内容が外に出ることはありません。

■ カレンダーでひと目
ひと月を開くと、やることが色付きのバーで見えます。数日にわたる予定もつながって見えます。

■ 今日だけまとめて
カレンダーで今日をタップすると、今日のやること、過ぎたやること、Dデーが1ページに並びます。

■ ホーム画面ウィジェット
今日のやること、週カレンダー、月カレンダー。アプリを開かなくても見えます。

■ そのほか
繰り返し、開始前の通知、ロック画面のカウントダウン、iCloud同期、天気、テーマカラー。

アカウントは不要です。
```

## 키워드 (100자 이내, 쉼표로 구분)

이름과 부제에 이미 있는 낱말은 넣지 않는다. 스토어가 이름·부제·키워드를 합쳐서 찾기 때문에
겹치면 자리만 버린다.

- 한국어: `일정,투두,todo,플래너,스케줄,메모,체크리스트,위젯,디데이,리마인더,루틴,다이어리,계획`
- English: `planner,schedule,tasks,reminder,widget,checklist,agenda,daily,organizer,simple,quick,natural language`
- 日本語: `予定,スケジュール,タスク,リマインダー,ウィジェット,手帳,プランナー,チェックリスト,メモ,習慣,簡単`

## 아직 확인하지 않은 것

영어와 일본어 문구는 원어민이 읽어보지 않았다. 올리기 전에 한 번 읽혀보는 편이 안전하다.
특히 일본어 이름의 `ToDo`와 본문의 `やること`가 섞여 있는데, 앱 안에서는 `やること`로
통일했고 검색에는 `ToDo`가 더 잡힐 것 같아 이름에만 썼다. 이건 추정이다.

다섯째 장(위젯)은 홈 화면을 손으로 꾸며서 찍어야 해서 아직 없다. 9월에 남은 사람들이 위젯으로
1인당 열두 번 들어왔으니, 넣을 값은 충분히 있다.
