# 개발 컨벤션

이 문서는 Mosco-iOS 프로젝트의 커밋 메시지 규칙과 브랜치 전략을 정리합니다.
버전을 어떻게 매기고 App Store에 무엇을 적어 올리는지는
[RELEASING.md](RELEASING.md)에 있습니다.

## 커밋 메시지 컨벤션

[Conventional Commits](https://www.conventionalcommits.org/) 형식을 따릅니다.

```
<type>(<scope>): <subject>

<body>

<footer>
```

- **type** (필수)
  - `feat`: 새로운 기능 추가
  - `fix`: 버그 수정
  - `refactor`: 동작 변화 없는 코드 개선/구조 변경
  - `style`: 코드 포맷팅, 세미콜론 등 스타일 변경 (로직 변경 없음)
  - `docs`: 문서 수정 (README, 주석 등)
  - `test`: 테스트 코드 추가/수정
  - `chore`: 빌드 설정, 패키지 관리, 기타 잡일
  - `perf`: 성능 개선
  - `ci`: CI/CD 설정 변경
- **scope** (선택): 변경 범위. 화면명, 모듈명 등 (예: `login`, `network`)
- **subject** (필수): 무엇을 했는지 명령문으로, 마침표 없이, 50자 이내
  - 예: `feat(login): 소셜 로그인 버튼 추가`
- **body** (선택): 왜 이렇게 변경했는지, 무엇이 달라지는지 설명. 한 줄 요약으로 부족할 때만 작성
- **footer** (선택): 관련 이슈 참조 (`Closes #12`), Breaking Change 명시

### 예시

```
feat(home): 홈 화면 무한 스크롤 적용

페이지네이션 API 연동 완료. 스크롤 하단 도달 시 다음 페이지 로드.

Closes #24
```

```
fix(auth): 토큰 만료 시 재로그인 화면으로 이동하지 않던 버그 수정
```

## 브랜치 전략

**GitHub Flow**를 따릅니다. `main`은 항상 배포 가능한 상태를 유지합니다.

- `main`: 안정 브랜치
- `feature/<설명>`: 새 기능 개발 (예: `feature/login-screen`)
- `fix/<설명>`: 버그 수정 (예: `fix/crash-on-launch`)
- `refactor/<설명>`: 리팩터링
- `chore/<설명>`: 설정, 의존성 등 기타 작업

작업 흐름:

1. `main`에서 브랜치 생성
2. 작업 후 커밋 (컨벤션 준수)
3. PR 생성 → 셀프 리뷰 후 `main`에 머지
4. 머지된 브랜치는 삭제

## PR

PR 템플릿은 [.github/pull_request_template.md](.github/pull_request_template.md)를 사용합니다. 혼자 작업하더라도 변경 이력을 남기고 회고하기 위해 작은 단위로 PR을 나누는 것을 권장합니다.
