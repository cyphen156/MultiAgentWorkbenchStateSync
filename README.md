# MultiAgentPrivateRulesSync

MultiAgentCrossReview의 RuleSync와 함께 쓰는 **private markdown rule vault** 공개 예시입니다.

이 저장소는 MIT 공개 예시/템플릿입니다.  
실제 개인 선호, 프로젝트별 비공개 규칙, 로컬 경로가 들어간 파일은 이 저장소가 아니라 사용자가 직접 만든 **private repository**에 보관하세요.

## 역할

| 저장소 | 역할 |
|---|---|
| `MultiAgentCrossReview` | 공개 워크벤치. RuleSync 엔진, 범용 규칙, 프로젝트 템플릿을 포함합니다. |
| `MultiAgentPrivateRulesSync` | 공개 예시 vault. private rules vault의 디렉터리 형태만 보여줍니다. |
| 사용자의 private rules vault | 실제 `UserSettings/**/*.md`, 실제 `Projects/<name>/RULES.md`를 보관하는 비공개 SSOT입니다. |

RuleSync는 선택 기능입니다.  
한 대의 머신에서만 작업하고 로컬 룰을 직접 관리한다면 private rules vault를 만들 필요가 없습니다.  
여러 머신에서 같은 개인 설정과 프로젝트별 룰을 이어 써야 할 때만 이 예시를 복사해 private repository를 구성합니다.

## 구조

```text
MultiAgentPrivateRulesSync/
├─ README.md
├─ LICENSE
├─ .gitignore
├─ UserSettings/
│  ├─ preferences.md
│  ├─ session.md
│  └─ machines/
│     └─ EXAMPLE-HOST.md
└─ Projects/
   └─ ExampleProject/
      └─ RULES.md
```

## 사용 방법

1. 이 공개 예시를 참고해 본인 소유의 private repository를 만듭니다.
2. private repository를 각 머신의 원하는 경로에 clone합니다.
3. MultiAgentCrossReview 워크트리에서 로컬 RuleSync 설정 파일을 만듭니다.

```powershell
Copy-Item .\Packages\RuleSync\rulesync.config.example.psd1 .\Packages\RuleSync\rulesync.config.psd1
```

4. gitignore 대상인 `rulesync.config.psd1`에 private vault clone 경로를 지정합니다.

```powershell
@{
    VaultRoot = 'D:\Private\MyRulesVault'
    WorktreeRoot = ''
}
```

5. private vault의 룰을 MultiAgentCrossReview 워크트리로 가져옵니다.

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Pull
```

6. 워크트리에서 수정한 룰을 private vault로 되돌립니다.

```powershell
.\Packages\RuleSync\rulesync.ps1 -Direction Push
```

## SSOT

사용자의 private rules vault가 private markdown rules의 SSOT입니다.

MultiAgentCrossReview 공개 워크벤치는 RuleSync 엔진, 범용 규칙, 템플릿, 예시만 보관합니다. 실제 개인 설정과 프로젝트별 비공개 규칙은 공개 워크벤치에 커밋하지 않습니다.

## 동기화 대상

RuleSync가 다루는 파일:

```text
UserSettings/**/*.md
Projects/<name>/RULES.md
```

RuleSync가 다루지 않는 파일:

```text
README.md
Projects/<name>/baseline/**
Projects/<name>/edit/**
secrets/tokens/databases/session JSONL
```

`README.md`는 공개 안내 문서입니다. private vault에는 실제 룰 데이터만 둡니다.

## 보안

이 예시는 공개 저장소이므로 실제 개인 설정, 비공개 프로젝트 규칙, 절대경로, 토큰, 세션 JSONL을 넣지 마세요.

실제 운용 저장소는 반드시 private repository로 만들고, 필요하면 조직/계정 권한도 제한하세요.

## License

MIT. 자유롭게 사용·수정·배포할 수 있으며 저작권 고지와 라이선스는 유지해야 합니다.
