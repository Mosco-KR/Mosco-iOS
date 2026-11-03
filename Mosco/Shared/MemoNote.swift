import Foundation
import SwiftData

/// 메모 한 장. **할 일이 아니다** — 체크도, 날짜도, 카테고리도 없다.
///
/// ## 왜 할 일로 안 만들었나
///
/// 처음에는 '날짜 없는 할 일'을 메모라고 불렀다. 그런데 그건 여전히 할 일이다 —
/// 체크박스가 붙어 있고, 끝내면 내려가고, 카테고리가 따라붙는다. **적어두고 싶은
/// 것**(사 올 것, 들은 말, 나중에 볼 링크, 생각)에는 그 껍데기가 전부 군더더기다.
/// 그래서 메모는 제 모델을 갖는다. 할 일 탭은 건드리지 않는다 — 날짜 안 정한
/// 할 일은 지금까지처럼 거기 '날짜 없음' 칸에 그대로 선다.
///
/// ## 저장 규칙
///
/// 모든 속성에 인라인 기본값이 있는 건 **CloudKit 미러링 요구사항**이다(`TodoItem`과
/// 같은 이유) — 옵셔널이거나 기본값을 가져야 하고, `@Attribute(.unique)`는 못 쓴다.
@Model
final class MemoNote {
    var id: UUID = UUID()
    /// 적은 글 전부. **제목 칸을 따로 두지 않는다** — 메모장에서 제목을 먼저
    /// 묻는 것만큼 적는 걸 막는 일이 없다. 첫 줄이 곧 제목이고(`title`),
    /// 목록에는 그 아래가 미리보기로 붙는다.
    var body: String = ""
    var createdAt: Date = Date.now
    /// 마지막으로 고친 때. 목록은 이 순서로 선다 — 메모는 방금 만진 것을 다시
    /// 볼 일이 가장 잦다.
    var updatedAt: Date = Date.now
    /// 맨 위에 고정. 장 보는 목록처럼 며칠씩 다시 여는 것이 있다.
    var isPinned: Bool = false

    init(body: String = "") {
        self.id = UUID()
        self.body = body
        self.createdAt = .now
        self.updatedAt = .now
    }

    /// 목록에 세울 제목 — **첫 줄**이다. 비어 있으면 화면이 "새 메모"라고 부른다.
    var title: String {
        body.split(separator: "\n", omittingEmptySubsequences: false)
            .first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
    }

    /// 제목 아래에 붙는 미리보기 — 둘째 줄부터, 줄바꿈은 공백으로 눕힌다.
    /// 목록에서 한 장이 화면을 다 먹지 않게.
    var preview: String {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: false).dropFirst()
        return lines
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
