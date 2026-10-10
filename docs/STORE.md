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
무엇부터 할지 정리된다 → 달력에서 한눈에 본다"가 이어지게 했다. 넷째와 다섯째는 들어온
사람에게 매일 다시 열 이유(하루 페이지, 위젯)를 보여준다. 9월에 남은 사람들은 위젯으로 한
사람당 열두 번씩 들어왔다.

**둘째 장이 바뀌었다.** 예전 둘째 장은 오늘 페이지였는데, 그 탭이 없어지고 할 일 탭이
생겼다. 할 일 탭은 달력이 답하지 않는 질문 — "무엇부터 하지" — 에 답하는 화면이라,
"적는다 → 정리된다"의 둘째 칸으로도 더 맞다.

| 장 | 화면 | 한국어 | English | 日本語 |
|---|---|---|---|---|
| 1 | 입력창에 한 줄을 친 순간, 시간 칩이 뜬 모습 | "저녁 약속 오후 7시"<br>한 줄이면 끝나요 | "Dinner 7pm"<br>One line. Done. | 「夕食 午後7時」<br>一行で完了 |
| 2 | 할 일 탭(맨 위 디데이 카드, 지난 할 일·날짜 없음 묶음) | 무엇부터 할지<br>한 화면에 | What to do first,<br>on one screen | 何からやるか<br>ひと画面で |
| 3 | 달력 홈, 할 일 막대가 찬 한 달 | 한 달치가<br>한 화면에 | Your whole month<br>at a glance | ひと月分が<br>ひと画面に |
| 4 | 하루 페이지의 시간표 | 오늘 하루가<br>시간순으로 | Your whole day,<br>hour by hour | 今日一日が<br>時間順に |
| 5 | 홈 화면 위젯 (아직 없음) | 열지 않아도<br>보여요 | Without opening<br>the app | 開かなくても<br>見える |

다섯째 장(위젯)은 홈 화면을 손으로 꾸며서 찍어야 해서 아직 없다.

**1·3장이 사실상 같은 그림이라는 문제가 남아 있다.** 둘 다 달력 홈이고, 다른 것은 아래
입력창 한 줄뿐이다. 검색 결과에는 이 둘이 나란히 뜨므로 넘겨볼 이유가 되지 못한다. 1장이
보여줘야 하는 건 "한 줄을 쳤더니 결과가 생겼다"인데 지금 가진 장면에는 그 순간이 없다 —
`compose` 다음 상태를 장면으로 하나 더 만들어야 풀린다.

### 헤더와 검색 결과 자산 (iOS 27~)

제품 페이지 맨 위와 검색 결과에 쓰이는 별도의 그림이다. 미리보기 스크린샷과 다른
칸이고, 언어마다 따로 올린다. 만드는 것은 `tools/make_creative_assets.swift`다.

**가운데로 몰아 넣어야 한다.** 애플 가이드가 "focal point artwork를 구도 가운데에
둬서 잘리지 않게 하라"고 못박고 있는데, 같은 자산이 자리마다 다른 비율로 잘려
쓰이기 때문이다. 첫 판은 막대를 맨 왼쪽, 워드마크를 맨 오른쪽에 뒀다가 1:1로 자르면
양쪽이 다 날아갔다. 그래서 **안전 영역을 긴 변이 아니라 짧은 변 기준으로** 잡는다
— 가장 좁게 잘리는 경우가 정사각이고, 그때 남는 폭이 높이와 같다. 스크립트가
16:9와 1:1로 잘라 본 증명 이미지를 같이 뽑으니 그걸로 확인한다.

**크기와 형식에 함정이 둘 있다.** 헤더 칸은 **PNG만 받는다** — JPEG를 올리면
"파일 확장자가 유효하지 않습니다"가 뜬다. 그런데 허용 크기 중 큰 쪽(5244×2950)
PNG는 13MB라 업로드가 안 걸린다. 그래서 **3840×1646**으로 간다. 검색 결과 칸은
JPEG도 받고 크기는 1920×1280이면 된다.

스크린샷이 아직 없을 때도 만들 수 있다 — 앱 아이콘의 보라 그라데이션과 유리 막대를
키운 그림이라 화면 캡처를 안 쓴다.

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

찍는 것은 `tools/capture_screenshots.sh` 한 줄이고, 문구와 기기 틀을 입히는 것은
`tools/compose_screenshots.swift`다. Canva는 더 쓰지 않는다 — 1242로 요구해도 1237로
내주던 것과 내보내기 URL이 한 칸씩 밀리던 것, 둘 다 사라졌다.

**찍기 전에 충분히 기다려야 한다.** 처음엔 실행 후 4초에 찍었는데 달력이 통째로 비어
나왔다. 할 일 탭에는 데이터가 멀쩡히 보이는데 달력만 빈 것이라 데이터 문제로 보이지만,
시드가 스물한 개를 넣고 달 격자가 다시 그려지는 데 그보다 오래 걸리는 것뿐이다.
9초로 늘리니 해결됐다.

장면은 넷이다 — `compose`(한 줄을 친 달력 홈), `month`(달력 홈), `today`(달력에서 연 하루
페이지), `todos`(할 일 탭). 시간표는 `today`에 `-dayViewMode timeline`을 붙인다. 언어는
`ko`·`en`·`ja`.

`todos`는 할 일 탭이 생기면서 추가했다. 이 장면을 위해 **예시 데이터도 손봤다** — 디데이로
표시한 것 셋(제주 여행·생일 파티·발표), 지난 할 일 둘, 날짜를 안 정한 할 일 둘을 넣었다.
그게 없으면 디데이 카드도 '지난 할 일'·'날짜 없음' 묶음도 비어서, 이 탭에서 만든 것이
절반만 찍힌다.

문구와 기기 틀을 입히는 것은 `tools/compose_screenshots.swift`다. 결과는
`store/screenshots/`에 **1206×2622**로 들어간다.

**이 크기는 한 번 바뀌었다.** 예전에는 1242×2688(6.5형)이었다. 애플이 스크린샷 칸을
'15.5cm 또는 15.9cm 디스플레이의 iPhone' 하나로 합치면서 받는 크기도 바뀌었고, 지금은
**1179×2556과 1206×2622 둘뿐**이다. 1242×2688을 올리면 거부된다. 큰 쪽을 쓴다.

Canva는 더 쓰지 않는다. 거기서 당한 함정 둘 — 1242를 요구해도 비율을 지키느라 1237로
내주던 것, 내보내기 URL이 순서가 아니라 경로를 봐야 짝이 맞던 것 — 은 합성을 코드로
가져오면서 같이 사라졌다. 좌우를 배경색으로 채우던 `tools/pad_screenshots.swift`도
그래서 필요 없어졌다.

## 이 버전의 새로운 기능

스토어에 올라가 있는 건 1.4.1(빌드 8)이고, 그 뒤로 머지된 것이 #31~#40이다. 사용자 눈에
보이는 변화만 추렸다 — 분석 식별 수정(#34)과 문서(#35)는 뺐다.

가장 큰 변화는 **탭 구성이 바뀐 것**이다. 할 일 탭이 생기고 오늘 탭이 없어졌다. 쓰던 사람은
열자마자 알아채는 종류의 변화라 맨 앞에 둔다. 버전 번호는 아직 안 올렸다 —
`MARKETING_VERSION`이 1.4.1 그대로다.

### 한국어

```
할 일 탭이 생겼어요.

지난 할 일, 날짜를 안 정한 할 일, 앞으로 올 할 일을 한 화면에서 급한 순서로 봐요.
맨 위에는 디데이가 가까운 순서로 서요.

■ 탭이 둘이 됐어요
달력에서 날짜를 누르면 그날 페이지가 열려요. 오늘 탭이 하던 일을 달력이 그대로 해요.

■ 하루 마무리 알림
저녁에 남은 할 일을 한 번에 알려드려요. 시간을 안 적은 할 일도 이제 알림을 받아요.

■ 주간 달력이 일~토로 돌아왔어요
요일 자리가 고정돼서 읽기 쉬워요. 옆으로 밀면 보던 요일의 다음 주로 가요.

■ 고친 것
위젯에서 끝낸 할 일이 그대로 보이던 것을 고쳤어요.
카테고리가 없는 할 일이 알림을 못 받던 것을 고쳤어요.
영어와 일본어에서 비어 있던 문구를 채웠어요.
```

### English

```
There's a To-Do tab now.

Overdue, undated, and upcoming to-dos on one screen, in the order they need you.
D-Days sit at the top, nearest first.

■ Two tabs
Tap a date in the calendar to open that day. The calendar now does what the Today tab did.

■ Daily Wrap-Up
One reminder in the evening for whatever is left. To-dos without a time get reminded too.

■ The week strip runs Sunday to Saturday again
Each weekday keeps its place, so the row reads at a glance. Swipe and you land on the same weekday next week.

■ Fixed
Completed to-dos stayed visible in the widget.
To-dos without a category never got reminders.
Filled in text that was missing in English and Japanese.
```

### 日本語

```
「やること」タブができました。

過ぎたやること、日付なしのやること、これから来るやることを、急ぐ順にひと画面で見られます。
一番上にはDデーが近い順に並びます。

■ タブが2つになりました
カレンダーで日付をタップすると、その日のページが開きます。「今日」タブの役割はカレンダーが引き継ぎます。

■ 一日のまとめ通知
夜に、残っているやることをまとめてお知らせします。時間を書いていないやることにも通知が届きます。

■ 週カレンダーが日〜土に戻りました
曜日の位置が固定されるので、ひと目で読めます。横にスワイプすると、見ていた曜日の翌週に移ります。

■ 修正
ウィジェットで終えたやることが残って見えていた問題を直しました。
カテゴリのないやることに通知が届かなかった問題を直しました。
英語と日本語で抜けていた文言を補いました。
```

## 홍보 문구 (170자 이내)

- 한국어: `"내일 오후 3시 치과"처럼 한 줄만 적으면 시간과 분류가 알아서 붙어요. 달력을 열면 바로 적을 수 있어요.`
- English: `Type "Dentist 3pm" and the time and category fill themselves in. Open the calendar and start writing right away.`
- 日本語: `「歯医者 午後3時」と一行書くだけで、時間と分類が自動で入ります。カレンダーを開いてすぐ書けます。`

## 설명

**2026-10-10에 고쳤다.** 할 일 탭이 생기고 오늘 탭이 없어지면서, "달력에서 오늘을 누르면
오늘 할 일·지난 할 일·디데이가 한 페이지에" 라는 대목이 틀린 말이 됐다. 지난 할 일과 디데이는
이제 할 일 탭에 있다. 스토어에 올라가 있는 설명은 아직 옛 문장이므로 **다음 심사 때 같이
올려야 한다.**

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

■ 하루만 모아서
달력에서 날짜를 누르면 그날 할 일이 한 페이지에 나와요. 시간표로도 볼 수 있어요.

■ 무엇부터 할지는 할 일 탭에서
지난 할 일, 날짜를 안 정한 할 일, 앞으로 올 일이 급한 순서로 모여요.
맨 위에는 디데이가 가까운 순서로 서요.

■ 홈 화면 위젯
오늘 할 일, 주간 달력, 월 달력 위젯이 있어요. 앱을 안 열어도 보여요.

■ 그 밖에
반복 일정, 시작 전 알림, 하루 마무리 알림, 잠금화면 남은 시간 표시, iCloud 동기화, 날씨, 테마 색.

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

■ One day at a time
Tap a date on the calendar to see that day on one page. There's an hour-by-hour view too.

■ What to do first lives in the To-Do tab
Overdue, undated, and upcoming to-dos, in the order they need you.
D-Days sit at the top, nearest first.

■ Home Screen widgets
Today's to-dos, a week calendar, and a month calendar. See them without opening the app.

■ Also
Repeating to-dos, reminders before start, a daily wrap-up, Lock Screen countdown, iCloud sync, weather, theme color.

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

■ 一日ずつまとめて
カレンダーで日付をタップすると、その日のやることが1ページに並びます。時間順の表示もあります。

■ 何からやるかは「やること」タブで
過ぎたやること、日付なしのやること、これから来るやることが急ぐ順に集まります。
一番上にはDデーが近い順に並びます。

■ ホーム画面ウィジェット
今日のやること、週カレンダー、月カレンダー。アプリを開かなくても見えます。

■ そのほか
繰り返し、開始前の通知、一日のまとめ通知、ロック画面のカウントダウン、iCloud同期、天気、テーマカラー。

アカウントは不要です。
```

## 키워드 (100자 이내, 쉼표로 구분)

이름과 부제에 이미 있는 낱말은 넣지 않는다. 스토어가 이름·부제·키워드를 합쳐서 찾기 때문에
겹치면 자리만 버린다.

영어에서 `simple`을 뺐다 — 101자라 100자 한도를 1자 넘겼고, 한 낱말을 빼야 한다면 검색량이
가장 낮을 쪽이 그것이다. 한국어(50자)와 일본어(53자)는 아직 한도의 절반을 안 썼다. 넣을
낱말을 더 찾아볼 여지가 있다.

- 한국어: `일정,투두,todo,플래너,스케줄,메모,체크리스트,위젯,디데이,리마인더,루틴,다이어리,계획`
- English: `planner,schedule,tasks,reminder,widget,checklist,agenda,daily,organizer,quick,natural language`
- 日本語: `予定,スケジュール,タスク,リマインダー,ウィジェット,手帳,プランナー,チェックリスト,メモ,習慣,簡単`

## 아직 확인하지 않은 것

영어와 일본어 문구는 원어민이 읽어보지 않았다. 올리기 전에 한 번 읽혀보는 편이 안전하다.
특히 일본어 이름의 `ToDo`와 본문의 `やること`가 섞여 있는데, 앱 안에서는 `やること`로
통일했고 검색에는 `ToDo`가 더 잡힐 것 같아 이름에만 썼다. 이건 추정이다.

다섯째 장(위젯)은 홈 화면을 손으로 꾸며서 찍어야 해서 아직 없다. 9월에 남은 사람들이 위젯으로
1인당 열두 번 들어왔으니, 넣을 값은 충분히 있다.
