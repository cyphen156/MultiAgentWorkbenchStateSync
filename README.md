# MultiAgentWorkbenchStateSync

MultiAgentCrossReview의 사용자 관리 상태를 옮기는 버튼형 PowerShell 동기화 도구입니다.

이 저장소는 공개 MIT 도구 저장소입니다. 실제 검토 기록, 로컬 설정, 프로젝트 경로, 원문 세션, 토큰, 머신별 설정은 저장하지 않습니다.

## 무엇을 동기화하나

WorkbenchStateSync는 공개 MultiAgentCrossReview 프레임워크 저장소에 두면 안 되는 가변 상태를 복사합니다.

포함:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
Reviews/<review-id>/**
```

제외:

```text
UserSettings/README.md
Reviews/README.md
Reviews/_TEMPLATE/**
Reviews/run-review.ps1
Projects/<name>/baseline/**
Projects/<name>/edit/**
*.jsonl, *.db, *.sqlite, *.key, *.pem, *.env, *.user, *.log
```

Codex·Claude 원문 대화(JSONL)는 WorkbenchStateSync 대상이 아닙니다. 그것은 별도의 세션 운반 도구를 씁니다.

## 저장소 역할

| 저장소 | 역할 |
|---|---|
| `MultiAgentCrossReview` | 공개 프레임워크: 프로세스 문서, 템플릿, 검토 러너, 예시, 패키지 사본 |
| `MultiAgentWorkbenchStateSync` | 공개 동기화 도구: 이식 가능한 Start/Finish 래퍼와 복사 규칙 |
| 사용자 상태 저장소 | 실제 `UserSettings/`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/` 기록을 두는 사용자 지정 저장소(보통 비공개) |

## 설정

먼저 상태 저장소를 clone하거나 생성합니다.

```powershell
git clone https://github.com/<you>/<your-state-repo>.git D:\State\MultiAgentWorkbenchState
```

예시 config를 복사합니다.

```powershell
Copy-Item .\workbenchstatesync.config.example.psd1 .\workbenchstatesync.config.psd1
```

`workbenchstatesync.config.psd1`을 편집합니다.

```powershell
@{
    VaultRoot = 'C:\Path\To\MultiAgentWorkbenchStateVault'
    WorktreeRoot = 'C:\Path\To\MultiAgentCrossReview'
}
```

`VaultRoot`는 상태 저장소의 로컬 clone 경로, `WorktreeRoot`는 로컬 MultiAgentCrossReview 워크벤치입니다. `WorktreeRoot`가 비어 있으면 현재 디렉터리를 씁니다.

## 일상 사용

상태를 워크벤치로 가져오기(pull):

```powershell
.\Start.ps1
```

상태를 상태 저장소로 되돌려 보내고 커밋·푸시:

```powershell
.\Finish.ps1
```

유용한 변형:

```powershell
.\Start.ps1 -DryRun
.\Finish.ps1 -DryRun
.\Start.ps1 -Force
.\Finish.ps1 -NoOverwrite
.\Finish.ps1 -SkipGitPush
.\Finish.ps1 -CommitMessage 'workbench state: update desktop'
```

저수준 복사 모드:

```powershell
.\workbenchstatesync.ps1 -Direction Pull
.\workbenchstatesync.ps1 -Direction Push
```

## 예시 상태 레이아웃

`examples/workbench-state/`에 정제된 상태 저장소 형태가 있습니다. 지어낸 예시가 아니라 **실제로 진행된 교차 검토 세션**(`2026-07-03_MathUnitTypeDesign` — Math·단위·좌표 자료형 설계)을 담아, WorkbenchStateSync가 옮기는 상태의 형태와 실제 검토 내용을 함께 보여줍니다.

```text
examples/workbench-state/
  UserSettings/preferences.example.md
  Projects/MultiAgentCrossReview/RULES.md
  Reviews/2026-07-03_MathUnitTypeDesign/
    README.md
    Claud/REVIEW.md
    Claud/artifacts/*.h
    Codex/REVIEW.md
    DECISION.md
```

이 예시가 보여주는 것은 WorkbenchStateSync가 옮기는 데이터입니다: 사용자 설정, 프로젝트별 규칙, 실제 검토 기록. 이 파일들의 실제 사본은 공개 프레임워크 저장소가 아니라 사용자 상태 저장소에 둡니다.

## 충돌 동작

WorkbenchStateSync는 내용이 다른 대상 파일을 조용히 덮어쓰지 않습니다.

소스와 대상이 같은 상대 경로에 서로 다른 내용의 파일을 가질 때:

1. 대상 파일을 타임스탬프가 붙은 `.bak-*`로 백업합니다.
2. `-Force`가 없으면 복사를 건너뜁니다.
3. `-Force`가 있으면 백업 후 소스 파일이 대상을 덮어씁니다.

Push 모드는 흔한 토큰 형태의 시크릿을 스캔합니다. 일치한 값은 출력하지 않습니다.

## 라이선스

MIT.
