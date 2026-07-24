# Itasca 3DEC Skill

An open-format Agent Skill for developing, troubleshooting, running, and validating Itasca 3DEC 9.x projects on Windows.

[繁體中文](#繁體中文) · [Agent Skills specification](https://agentskills.io/specification) · [Itasca documentation](https://docs.itascasoftware.com/)

## Features

- Works with 3DEC `.dat`, FISH, and embedded-Python workflows.
- Runs data files through `3dec9_console.exe` with logging, timeout handling, and error detection.
- Searches version-matched local Itasca HTML documentation.
- Provides validation guidance for geometry, zoning, mechanical, fluid, coupled, and staged models.
- Keeps generated `.sav`, logs, crash dumps, and proprietary project data out of published skill content.

## Requirements

- Windows with PowerShell.
- A locally installed and licensed Itasca 3DEC 9.x.
- Local access to `3dec9_console.exe` and the installed documentation.
- For Itasca Software Subscription builds, an active licensed 3DEC GUI session before console execution.

This repository does not contain Itasca executables, documentation, licenses, or proprietary model data.

## Install

Clone the repository into a skills directory recognized by your agent.

### OpenAI Codex

```powershell
git clone https://github.com/hotheartguy/itasca-3dec-skill.git `
    "$env:USERPROFILE\.codex\skills\itasca-3dec-skill"
```

Start a new Codex session after installation.

### Claude Code

```powershell
git clone https://github.com/hotheartguy/itasca-3dec-skill.git `
    "$env:USERPROFILE\.claude\skills\itasca-3dec-skill"
```

### VS Code with GitHub Copilot

```powershell
git clone https://github.com/hotheartguy/itasca-3dec-skill.git `
    "$env:USERPROFILE\.agents\skills\itasca-3dec-skill"
```

VS Code also supports project skills under `.github/skills/`, `.claude/skills/`, or `.agents/skills/`.

## Use

Ask the agent to use the skill for a 3DEC task:

```text
Use itasca-3dec-skill to inspect this project and run step1_geometry.dat.
```

For an Itasca Software Subscription installation:

1. Start 3DEC normally and wait for the GUI and license session to become active.
2. Keep the GUI open.
3. Ask the agent to run the desired `.dat` stage.
4. Review the generated log and numerical acceptance criteria, not only the process exit code.

Run a data file manually:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File '<skill-dir>\scripts\run-3dec.ps1' `
    -DataFile '.\step1_geometry.dat' `
    -TimeoutSeconds 3600
```

Search local documentation:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File '<skill-dir>\scripts\search-3dec-docs.ps1' `
    -Query 'block contact compute-stiffness'
```

## Documentation Priority

1. Installed console prompt help for exact command grammar.
2. Local documentation shipped with the installed executable.
3. The matching 3DEC version in the [official documentation archive](https://docs.itascasoftware.com/).
4. Other releases only for background concepts.

## Repository Layout

```text
itasca-3dec-skill/
├── README.md
├── LICENSE
├── SKILL.md
├── agents/
│   └── openai.yaml
├── references/
│   ├── cli-python.md
│   └── validation.md
└── scripts/
    ├── run-3dec.ps1
    └── search-3dec-docs.ps1
```

## License

MIT. See [LICENSE](LICENSE).

3DEC and Itasca are trademarks of their respective owner. This independent community skill is not affiliated with or endorsed by Itasca.

---

## 繁體中文

這是一個採用開放 Agent Skills 格式的 Itasca 3DEC 9.x 工作流程技能，協助 AI 在 Windows 上檢查、修改、執行及驗證 `.dat`、FISH 與 embedded-Python 模型。

### 使用需求

- Windows 與 PowerShell。
- 已安裝並具有有效授權的 Itasca 3DEC 9.x。
- AI 代理必須能存取本機 `3dec9_console.exe`、專案檔案及說明文件。
- 訂閱版必須先啟動 3DEC GUI、完成登入或授權，再執行 CLI。

### 建議工作流程

1. 讓代理讀取專案的 `AGENTS.md` 與 `SKILL.md`。
2. 確認 3DEC 版本、上游 `.sav`、輸入 `.dat` 及幾何檔案。
3. 優先查詢 console help 與同版本本機說明文件。
4. 透過 `scripts/run-3dec.ps1` 執行最小必要階段。
5. 檢查日誌、警告、收斂指標與模型狀態。
6. 不要將 `.sav`、暫存檔、授權資訊或專有模型資料上傳至公開儲存庫。

### 範例提示

```text
請使用 itasca-3dec-skill 檢查這個 3DEC 專案，執行 step1_geometry.dat，
並回報版本、耗時、日誌、警告、block/zone 數量及輸出存檔。
```
