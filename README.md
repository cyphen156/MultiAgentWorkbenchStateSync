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

포함/제외 규칙 전체는 [`STATE_MANIFEST.schema.md`](STATE_MANIFEST.schema.md)에, 실제 동기화되는 구조의 구체 예시는 [`examples/workbench-state/`](examples/workbench-state/)에 있습니다.

## 저장소 역할

| 저장소 | 역할 |
|---|---|
| `MultiAgentCrossReview` | 공개 프레임워크: 프로세스 문서, 템플릿, 검토 러너, 예시, 패키지 사본 |
| `MultiAgentWorkbenchStateSync` | 공개 동기화 도구: 이식 가능한 Start/Finish 래퍼와 복사 규칙 |
| 사용자 상태 저장소 | 실제 `UserSettings/`, `Projects/<name>/RULES.md`, `Reviews/<review-id>/` 기록을 두는 사용자 지정 저장소(보통 비공개) |

## 설치

새 머신에서는 초기화 스크립트 하나로 상태 저장소 clone, 로컬 설정, 상태 materialize, 선택적
baseline 갱신, 머신별 바로가기 생성을 처리합니다.

```powershell
.\Launchers\Initialize-NewMachine.ps1 `
  -WorkbenchRoot 'C:\Path\To\MultiAgentCrossReview' `
  -StateRepoUrl 'https://github.com/<you>/<your-state-repo>.git' `
  -StateRepoRoot 'D:\State\MultiAgentWorkbenchState'
```

이미 존재하는 self-contained Vault 안에서 실행할 때는 `StateRepoRoot`가 그 Vault 자체로 기본 설정되므로
다음처럼 실행할 수 있습니다.

```powershell
.\Launchers\Initialize-NewMachine.ps1 `
  -WorkbenchRoot 'C:\Path\To\MultiAgentCrossReview'
```

이 명령이 만드는 `workbenchstatesync.config.psd1`과 `Launchers\Shortcuts\*.lnk`는 머신별 절대경로를
포함하므로 Git에서 제외됩니다.

## 수동 설정

먼저 상태 저장소를 clone하거나 생성합니다.

```powershell
git clone https://github.com/<you>/<your-state-repo>.git D:\State\MultiAgentWorkbenchState
```

예시 config를 복사합니다.

```powershell
Copy-Item .\Launchers\workbenchstatesync.config.example.psd1 .\Launchers\workbenchstatesync.config.psd1
```

`workbenchstatesync.config.psd1`을 편집합니다.

```powershell
@{
    VaultRoot = 'C:\Path\To\MultiAgentWorkbenchStateVault'
    WorktreeRoot = 'C:\Path\To\MultiAgentCrossReview'
}
```

`VaultRoot`는 상태 저장소의 로컬 clone 경로, `WorktreeRoot`는 로컬 MultiAgentCrossReview 워크벤치입니다. `WorktreeRoot`가 비어 있으면 현재 디렉터리를 씁니다.

MultiAgentCrossReview의 `Packages/WorkbenchStateSync` 어댑터를 사용하는 경우에는 등록된 `ToolRoot`와
현재 워크벤치 경로를 실행 때 주입하므로 Vault 쪽 config가 없어도 됩니다.

## 일상 사용

상태를 워크벤치로 가져오기(pull):

```powershell
.\Launchers\Start.ps1
```

상태를 상태 저장소로 되돌려 보내고 커밋·푸시:

```powershell
.\Launchers\Finish.ps1
```

유용한 변형:

```powershell
.\Launchers\Start.ps1 -DryRun
.\Launchers\Finish.ps1 -DryRun
.\Launchers\Start.ps1 -Force
.\Launchers\Finish.ps1 -NoOverwrite
.\Launchers\Finish.ps1 -SkipGitPush
.\Launchers\Finish.ps1 -CommitMessage 'workbench state: update desktop'
```

저수준 복사 모드:

```powershell
.\Launchers\workbenchstatesync.ps1 -Direction Pull
.\Launchers\workbenchstatesync.ps1 -Direction Push
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

`.bak-*`는 충돌 증거이지만 동기화·커밋 대상은 아닙니다. 필요 없어진 백업은 사용자가 검토 후
정리하며, 도구가 자동으로 삭제하지 않습니다.

## 라이선스

MIT.
