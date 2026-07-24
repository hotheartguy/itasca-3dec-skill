---
name: itasca-3dec-skill
description: Develop, troubleshoot, automate, and validate Itasca 3DEC 9.x projects on Windows. Use when working with 3DEC .dat, FISH, or embedded-Python files; geometry imports; staged .sav workflows; console batch execution; local command/manual lookup; mechanical, fluid, or coupled convergence checks; or reproducible repository workflows around 3dec9_console.exe.
license: MIT
metadata:
  author: hotheartguy
  version: "1.0.0"
  compatibility: Requires Windows PowerShell and local access to Itasca 3DEC 9.x. Subscription builds require an active licensed 3DEC GUI session before console execution.
---

# Itasca 3DEC Skill

Use the installed 3DEC console and version-matched local documentation to make small, testable model changes. Treat numerical-model validation as part of implementation, not as a separate optional step.

## Workflow

1. Discover the project.
   - Read all applicable `AGENTS.md` files.
   - Identify the project root, entry `.dat` files, restore/save chain, geometry inputs, and generated artifacts.
   - Preserve existing coordinate transforms, geometry-set names, group names, and stage boundaries unless the task explicitly changes them.
2. Discover the installed 3DEC version.
   - Prefer `ITASCA_3DEC_CONSOLE` when set.
   - Otherwise locate `3dec9_console.exe` with `scripts/run-3dec.ps1`.
   - For an Itasca Software Subscription installation, launch the 3DEC GUI and confirm that its licensed session is active before starting `3dec9_console.exe`.
   - Prefer the local manual shipped with that installation. If online documentation is needed, use `https://docs.itascasoftware.com/` and select the 3DEC documentation family matching the installed major and minor version.
3. Verify syntax before editing.
   - Search local documentation with `scripts/search-3dec-docs.ps1`.
   - Use the `?` command hierarchy when documentation is unclear, for example `?`, `model ?`, or `block contact ?`.
   - Do not invent commands, keywords, FISH intrinsics, or convergence criteria.
4. Edit source inputs.
   - Keep `.dat`, FISH, Python, DXF, STL, and documentation changes focused.
   - Use FISH variables for repeated coordinates and parameters.
   - Keep source geometry and import paths synchronized.
   - Do not edit binary `.sav` files.
5. Run the narrowest useful stage.
   - Restore the nearest valid upstream `.sav` rather than rerunning the entire model when the change permits it.
   - Use `scripts/run-3dec.ps1` with an explicit timeout.
   - Inspect the generated log even when the process exits with code zero.
6. Validate the model.
   - Read `references/validation.md` when changing geometry, zoning, properties, boundary conditions, solving, or coupling.
   - Compare numerical metrics and model state, not only command completion.
   - Treat a timeout, `***` console error, traceback, new crash log, or unmet acceptance criterion as a failed run.
7. Report and preserve reproducibility.
   - Record the 3DEC version, data file, timeout, log path, warnings, convergence criteria, and generated save-state name.
   - Run repository whitespace checks when available.
   - Do not commit generated `.sav`, `.temp`, `.backup`, dump, or routine log files unless explicitly requested.

## Run 3DEC

For an Itasca Software Subscription installation, first start 3DEC from the desktop or run `3dec9_gui.exe`, then wait until the GUI has opened and the subscription license is available. Keep that GUI session open while starting the console. A headless console launched before the licensed GUI session may wait indefinitely or fail to produce a useful log.

Invoke the bundled runner from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass `
    -File '<skill-dir>\scripts\run-3dec.ps1' `
    -DataFile '.\step1_geometry.dat' `
    -TimeoutSeconds 3600
```

Override executable discovery when necessary:

```powershell
$env:ITASCA_3DEC_CONSOLE = 'C:\Program Files\Itasca\Itasca Software Subscription\exe64\3dec9_console.exe'
```

The runner passes a temporary `program exit` data file after the requested files. If a 3DEC command error aborts the input stack and leaves the console at `3dec>`, the runner terminates it at the timeout and returns a failure.

Read `references/cli-python.md` for CLI discovery, local documentation paths, and embedded-Python selection.

## Choose FISH or Python

- Use ordinary 3DEC commands for standard model construction and solving.
- Use FISH for cycle callbacks, model-object traversal, histories, halt criteria, and state stored inside `.sav`.
- Use embedded Python for array processing, result extraction, parameter studies, and integrations that benefit from the `itasca` Python API.
- Do not install the external `itasca` package merely to access an embedded 3DEC 9.x API. Use an external socket client only when a separate controlling process is an explicit requirement.

## Guardrails

- Never assume a fixed number of cycles is sufficient; demonstrate convergence or time adequacy.
- Never use mechanical ratio criteria as substitutes for fluid convergence.
- Never accept a model solely because a `.sav` file was produced.
- Never change installation files, licensing configuration, or global user settings without explicit approval.
- Never publish proprietary geometry, customer paths, license data, or model outputs with this skill.

## Resources

- `scripts/run-3dec.ps1`: run one or more `.dat` files with logging, error detection, timeout handling, and automatic clean exit.
- `scripts/search-3dec-docs.ps1`: search version-matched local HTML documentation.
- `references/cli-python.md`: executable discovery, console help, manual lookup, and embedded Python guidance.
- `references/validation.md`: geometry, mechanical, fluid, coupled, and repository validation criteria.
