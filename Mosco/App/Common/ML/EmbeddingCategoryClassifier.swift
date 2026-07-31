import Foundation
import NaturalLanguage

/// 학습 없이(inference만으로) 카테고리를 추천한다 — Apple 온디바이스 단어
/// 임베딩(NLEmbedding)으로 제목을 벡터화하고, 각 카테고리에 이미 들어있는
/// 할 일 제목들의 평균 벡터(centroid)와 코사인 유사도를 비교해서 제일 가까운
/// 카테고리를 고른다.
///
/// CoreML처럼 미리 훈련시켜 둔 모델이 아니라 그때그때 평균만 내는 것이라,
/// 카테고리를 방금 하나 만들고 할 일을 딱 하나만 넣어도 즉시 다음 추천에
/// 반영된다 — 사용자가 태그를 고를 때마다 그게 곧 "학습"이 되는 셈이다.
struct EmbeddingCategoryClassifier: CategoryClassifying {
    /// 유사도가 이보다 낮으면 추천하지 않는다 — 애매한 입력을 엉뚱한
    /// 카테고리로 확정하는 것보다, 추천을 안 하는 게 낫다.
    private static let similarityThreshold = 0.35

    /// 한국어 단어 임베딩이 이 OS/기기에 없을 수 있다(Apple이 온디바이스로
    /// 지원하는 언어 목록이 계속 바뀐다) — 그러면 이 값 자체가 nil이라
    /// 임베딩 경로가 통째로 못 쓰이는데, 그걸로 "기능이 아예 동작 안 한다"가
    /// 되면 안 되니 아래 classify()에서 항상 어휘 겹침 기반 대체 로직으로
    /// 한 번 더 시도한다.
    private static let embedding = NLEmbedding.wordEmbedding(for: .korean)

    func classify(_ text: String, categories: [TodoCategory], existingTodos: [TodoItem]) async -> TodoCategory? {
        guard !categories.isEmpty else { return nil }

        if let embedding = Self.embedding,
           let inputVector = sentenceVector(for: text, embedding: embedding),
           let result = classifyByEmbedding(
               inputVector: inputVector,
               categories: categories,
               existingTodos: existingTodos,
               embedding: embedding
           ) {
            return result
        }

        // 임베딩을 못 쓰거나(단어 임베딩이 이 기기에 없음) 유사도가 다 낮아서
        // 못 골랐을 때 — 글자 겹침만으로도 어느 정도는 맞힐 수 있다. 특히 카테고리
        // 이름 자체가 제목에 그대로 들어있는 흔한 경우(예: "운동" 카테고리에
        // "저녁 운동하기")는 이걸로 바로 잡힌다.
        return classifyByTextOverlap(text: text, categories: categories, existingTodos: existingTodos)
    }

    // MARK: - 임베딩 경로

    private func classifyByEmbedding(
        inputVector: [Double],
        categories: [TodoCategory],
        existingTodos: [TodoItem],
        embedding: NLEmbedding
    ) -> TodoCategory? {
        var best: (category: TodoCategory, similarity: Double)?
        for category in categories {
            let vectors = referenceTexts(for: category, existingTodos: existingTodos)
                .compactMap { sentenceVector(for: $0, embedding: embedding) }
            guard !vectors.isEmpty else { continue }

            let centroid = mean(vectors)
            let similarity = cosineSimilarity(inputVector, centroid)
            if best == nil || similarity > best!.similarity {
                best = (category, similarity)
            }
        }
        guard let best, best.similarity >= Self.similarityThreshold else { return nil }
        return best.category
    }

    /// 단어 벡터들의 평균으로 문장(제목) 벡터를 근사한다 — 문맥까지 보는 문장
    /// 임베딩은 아니지만, 짧은 할 일 제목 분류에는 이 정도로도 충분히 잘 갈린다.
    private func sentenceVector(for text: String, embedding: NLEmbedding) -> [Double]? {
        let vectors = tokenize(text).compactMap { embedding.vector(for: $0) }
        guard !vectors.isEmpty else { return nil }
        return mean(vectors)
    }

    private func mean(_ vectors: [[Double]]) -> [Double] {
        guard let first = vectors.first else { return [] }
        var sum = [Double](repeating: 0, count: first.count)
        for vector in vectors {
            for i in 0..<sum.count { sum[i] += vector[i] }
        }
        return sum.map { $0 / Double(vectors.count) }
    }

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        guard normA > 0, normB > 0 else { return 0 }
        return dot / (normA.squareRoot() * normB.squareRoot())
    }

    // MARK: - 어휘 겹침 대체 경로 (임베딩이 없어도 항상 동작)

    /// 정규화(공백 제거)한 입력이 카테고리 이름/기존 제목과 부분 문자열로
    /// 겹치는지만 본다 — 한국어는 조사가 붙어서("운동" → "운동하기") 정확한
    /// 토큰 일치보다 부분 포함 검사가 훨씬 잘 맞는다.
    private func classifyByTextOverlap(text: String, categories: [TodoCategory], existingTodos: [TodoItem]) -> TodoCategory? {
        let normalizedInput = normalize(text)
        guard !normalizedInput.isEmpty else { return nil }

        var best: (category: TodoCategory, score: Int)?
        for category in categories {
            let references = referenceTexts(for: category, existingTodos: existingTodos)
            var score = 0
            for reference in references {
                let normalizedRef = normalize(reference)
                guard !normalizedRef.isEmpty else { continue }
                if normalizedInput.contains(normalizedRef) || normalizedRef.contains(normalizedInput) {
                    score += 1
                }
            }
            if score > 0, best == nil || score > best!.score {
                best = (category, score)
            }
        }
        return best?.category
    }

    /// 이 카테고리와 비교할 텍스트들 — 실제로 담긴 할 일 제목들 + 카테고리
    /// 이름 자체. 아직 아무것도 안 담겼어도 이름만으로 어느 정도 유사도를
    /// 잴 수 있게 해서, "카테고리를 막 만들었을 땐 추천이 전혀 안 된다"는
    /// 콜드스타트 문제를 완화한다.
    private func referenceTexts(for category: TodoCategory, existingTodos: [TodoItem]) -> [String] {
        let memberTitles = existingTodos.filter { $0.category?.id == category.id }.map(\.title)
        return memberTitles + [category.name]
    }

    private func tokenize(_ text: String) -> [String] {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    private func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
