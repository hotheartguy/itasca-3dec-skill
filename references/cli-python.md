# CLI, Documentation, and Python

## Executable discovery

Use this order:

1. Explicit `-Executable`.
2. `ITASCA_3DEC_CONSOLE`.
3. `3dec9_console.exe` available on `PATH`.
4. The standard subscription installation:
   `C:\Program Files\Itasca\Itasca Software Subscription\exe64\3dec9_console.exe`.

Do not hardcode a user profile, license identifier, project path, or minor release number in a public workflow.

## Subscription license startup

The Itasca Software Subscription build may require an active licensed GUI session before command-line execution:

1. Start 3DEC normally or launch `3dec9_gui.exe`.
2. Wait until the GUI is fully open and any sign-in or license prompt has completed.
3. Keep the GUI process running.
4. Start `3dec9_console.exe` or `scripts/run-3dec.ps1`.

If the console produces no log and takes much longer than a known-good run, check for a hidden subscription sign-in or license prompt in the GUI. Before retrying, verify that an earlier `3dec9_console.exe` process is not still running. Do not start duplicate console runs against the same project directory.

## Console execution

Run a data file from its project root so relative imports resolve:

```powershell
& $threeDecConsole '.\model.dat'
```

When invoking bundled `.ps1` helpers on a machine with a restrictive execution policy, use a process-local bypass:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File '<skill-dir>\scripts\run-3dec.ps1' -DataFile '.\model.dat'
```

Do not change the user's machine-wide execution policy.

The console converts data-file arguments into `program call` operations. Multiple data-file arguments run in order. A successfully completed file normally returns to the `3dec>` prompt unless a later input issues `program exit`.

Do not rely on `--help`; builds may treat it as an ordinary ignored argument and enter the interactive console.

Use prompt help to discover the installed command grammar:

```text
?
model ?
block ?
block contact ?
flowknot ?
```

## Local documentation

Prefer documentation installed beside the executable:

```text
<exe64>\doc
<exe64>\doc\common\docproject\source\manual
<exe64>\doc\3dec
```

Set `ITASCA_DOC_ROOT` when the installation uses another layout. Search exact command names, FISH intrinsic names, error text, and theory headings before changing syntax.

Online documentation is a fallback. Match its 3DEC release to the installed program before using examples.

## Embedded Python

Recent 3DEC 9.x installations expose an embedded `itasca` Python module. Confirm that the local manual contains the 3DEC-Python API before depending on it.

Issue commands from embedded Python with:

```python
import itasca as it

it.command("""
model new
block create brick 0 10
""")
```

Use object and array APIs for result extraction only after verifying their names in the local Python API pages. APIs available in FLAC3D or PFC are not automatically available in 3DEC.

The public `itascaconsulting/itasca-python` repository provides external socket connectivity and FISH binary readers. Treat it as a separate integration option, not as a replacement for the embedded 3DEC 9.x API.
