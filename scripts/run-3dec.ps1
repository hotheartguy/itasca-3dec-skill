[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$DataFile,

    [string[]]$AdditionalDataFile = @(),

    [string]$Executable = $env:ITASCA_3DEC_CONSOLE,

    [string]$WorkingDirectory,

    [ValidateRange(1, 2147483)]
    [int]$TimeoutSeconds = 3600,

    [string]$LogFile,

    [switch]$EchoOutput
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-3DecExecutable {
    param([string]$RequestedExecutable)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if (-not [string]::IsNullOrWhiteSpace($RequestedExecutable)) {
        $candidates.Add($RequestedExecutable)
    }

    $command = Get-Command '3dec9_console.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        $candidates.Add($command.Source)
    }

    $candidates.Add(
        'C:\Program Files\Itasca\Itasca Software Subscription\exe64\3dec9_console.exe'
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    throw 'Cannot locate 3dec9_console.exe. Set -Executable or ITASCA_3DEC_CONSOLE.'
}

function Resolve-InputFile {
    param(
        [string]$Path,
        [string]$BaseDirectory
    )

    $candidate = $Path
    if (-not [IO.Path]::IsPathRooted($candidate)) {
        $candidate = Join-Path $BaseDirectory $candidate
    }

    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw "Data file not found: $candidate"
    }

    return (Resolve-Path -LiteralPath $candidate).Path
}

function Quote-ProcessArgument {
    param([string]$Value)
    return '"' + $Value.Replace('"', '\"') + '"'
}

$invocationDirectory = (Get-Location).Path

if (-not [string]::IsNullOrWhiteSpace($WorkingDirectory)) {
    $workingCandidate = $WorkingDirectory
    if (-not [IO.Path]::IsPathRooted($workingCandidate)) {
        $workingCandidate = Join-Path $invocationDirectory $workingCandidate
    }
    $resolvedWorkingDirectory = (Resolve-Path -LiteralPath $workingCandidate).Path
    $mainDataFile = Resolve-InputFile `
        -Path $DataFile `
        -BaseDirectory $resolvedWorkingDirectory
}
else {
    $mainDataFile = Resolve-InputFile `
        -Path $DataFile `
        -BaseDirectory $invocationDirectory
    $resolvedWorkingDirectory = Split-Path -Parent $mainDataFile
}

$resolvedAdditionalFiles = foreach ($additionalFile in $AdditionalDataFile) {
    Resolve-InputFile -Path $additionalFile -BaseDirectory $resolvedWorkingDirectory
}

$resolvedExecutable = Resolve-3DecExecutable -RequestedExecutable $Executable
$runIdentifier = [Guid]::NewGuid().ToString('N')
$temporaryDirectory = [IO.Path]::GetTempPath()
$exitDataFile = Join-Path $temporaryDirectory "3dec-agent-exit-$runIdentifier.dat"

if ([string]::IsNullOrWhiteSpace($LogFile)) {
    $logDirectory = Join-Path $resolvedWorkingDirectory '.itasca-agent\logs'
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dataName = [IO.Path]::GetFileNameWithoutExtension($mainDataFile)
    $resolvedLogFile = Join-Path $logDirectory "$dataName-$timestamp.log"
}
else {
    $logCandidate = $LogFile
    if (-not [IO.Path]::IsPathRooted($logCandidate)) {
        $logCandidate = Join-Path $resolvedWorkingDirectory $logCandidate
    }
    $logParent = Split-Path -Parent $logCandidate
    if (-not [string]::IsNullOrWhiteSpace($logParent)) {
        New-Item -ItemType Directory -Path $logParent -Force | Out-Null
    }
    $resolvedLogFile = [IO.Path]::GetFullPath($logCandidate)
}

$errorLogFile = Join-Path $resolvedWorkingDirectory 'errorlog.txt'
$errorLogTimestampBefore = $null
if (Test-Path -LiteralPath $errorLogFile -PathType Leaf) {
    $errorLogTimestampBefore = (Get-Item -LiteralPath $errorLogFile).LastWriteTimeUtc
}

$startedAt = Get-Date
$process = $null
$timedOut = $false
$licenseUnavailable = $false
$processExitCode = $null
$licenseGuidance = 'No licenses found. Open the 3DEC GUI, use Execute once and confirm that the license is active, keep the GUI open, then retry the CLI run.'

try {
    [IO.File]::WriteAllText($exitDataFile, "program exit`r`n", [Text.Encoding]::ASCII)

    $inputFiles = @($mainDataFile) + @($resolvedAdditionalFiles) + @($exitDataFile)
    $argumentString = ($inputFiles | ForEach-Object {
        Quote-ProcessArgument -Value $_
    }) -join ' '

    $processStartInfo = [Diagnostics.ProcessStartInfo]::new()
    $processStartInfo.FileName = $resolvedExecutable
    $processStartInfo.Arguments = $argumentString
    $processStartInfo.WorkingDirectory = $resolvedWorkingDirectory
    $processStartInfo.UseShellExecute = $false
    $processStartInfo.CreateNoWindow = $true
    $processStartInfo.RedirectStandardOutput = $true
    $processStartInfo.RedirectStandardError = $true

    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $processStartInfo
    if (-not $process.Start()) {
        throw "Unable to start 3DEC process: $resolvedExecutable"
    }

    $standardOutputBuilder = [Text.StringBuilder]::new()
    $standardErrorBuilder = [Text.StringBuilder]::new()
    $standardOutputBuffer = New-Object char[] 4096
    $standardErrorBuffer = New-Object char[] 4096
    $standardOutputTask = $process.StandardOutput.ReadAsync(
        $standardOutputBuffer,
        0,
        $standardOutputBuffer.Length
    )
    $standardErrorTask = $process.StandardError.ReadAsync(
        $standardErrorBuffer,
        0,
        $standardErrorBuffer.Length
    )
    $standardOutputComplete = $false
    $standardErrorComplete = $false
    $licenseProbe = ''
    $deadline = $startedAt.AddSeconds($TimeoutSeconds)
    $terminationRequested = $false

    while ($true) {
        if (-not $standardOutputComplete -and $standardOutputTask.IsCompleted) {
            $charactersRead = $standardOutputTask.GetAwaiter().GetResult()
            if ($charactersRead -eq 0) {
                $standardOutputComplete = $true
            }
            else {
                $chunk = [string]::new(
                    $standardOutputBuffer,
                    0,
                    $charactersRead
                )
                [void]$standardOutputBuilder.Append($chunk)
                $licenseProbe += $chunk
                if ($licenseProbe.Length -gt 512) {
                    $licenseProbe = $licenseProbe.Substring(
                        $licenseProbe.Length - 512
                    )
                }
                if (
                    $licenseProbe.IndexOf(
                        'No licenses found',
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
                ) {
                    $licenseUnavailable = $true
                }
                $standardOutputTask = $process.StandardOutput.ReadAsync(
                    $standardOutputBuffer,
                    0,
                    $standardOutputBuffer.Length
                )
            }
        }

        if (-not $standardErrorComplete -and $standardErrorTask.IsCompleted) {
            $charactersRead = $standardErrorTask.GetAwaiter().GetResult()
            if ($charactersRead -eq 0) {
                $standardErrorComplete = $true
            }
            else {
                $chunk = [string]::new(
                    $standardErrorBuffer,
                    0,
                    $charactersRead
                )
                [void]$standardErrorBuilder.Append($chunk)
                $licenseProbe += $chunk
                if ($licenseProbe.Length -gt 512) {
                    $licenseProbe = $licenseProbe.Substring(
                        $licenseProbe.Length - 512
                    )
                }
                if (
                    $licenseProbe.IndexOf(
                        'No licenses found',
                        [StringComparison]::OrdinalIgnoreCase
                    ) -ge 0
                ) {
                    $licenseUnavailable = $true
                }
                $standardErrorTask = $process.StandardError.ReadAsync(
                    $standardErrorBuffer,
                    0,
                    $standardErrorBuffer.Length
                )
            }
        }

        if (-not $terminationRequested -and -not $process.HasExited) {
            if ($licenseUnavailable) {
                $terminationRequested = $true
                try {
                    $process.Kill()
                }
                catch {
                    Write-Warning "Unable to terminate unlicensed 3DEC process: $($_.Exception.Message)"
                }
            }
            elseif ((Get-Date) -ge $deadline) {
                $timedOut = $true
                $terminationRequested = $true
                try {
                    $process.Kill()
                }
                catch {
                    Write-Warning "Unable to terminate timed-out 3DEC process: $($_.Exception.Message)"
                }
            }
        }

        if (
            $process.HasExited -and
            $standardOutputComplete -and
            $standardErrorComplete
        ) {
            break
        }

        Start-Sleep -Milliseconds 25
    }

    $process.WaitForExit()
    $standardOutput = $standardOutputBuilder.ToString()
    $standardError = $standardErrorBuilder.ToString()

    if (-not $timedOut -and -not $licenseUnavailable) {
        $processExitCode = $process.ExitCode
    }

    $logSections = [System.Collections.Generic.List[string]]::new()
    $logSections.Add("Executable: $resolvedExecutable")
    $logSections.Add("Working directory: $resolvedWorkingDirectory")
    $logSections.Add("Data files: $($inputFiles -join '; ')")
    $logSections.Add("Started: $($startedAt.ToString('o'))")
    $logSections.Add("Timed out: $timedOut")
    $logSections.Add("License unavailable: $licenseUnavailable")
    $logSections.Add("Process exit code: $processExitCode")
    $logSections.Add("`r`n===== STDOUT =====`r`n$standardOutput")
    $logSections.Add("`r`n===== STDERR =====`r`n$standardError")
    if ($licenseUnavailable) {
        $logSections.Add("`r`n===== ACTION REQUIRED =====`r`n$licenseGuidance")
    }

    $newErrorLog = $false
    if (Test-Path -LiteralPath $errorLogFile -PathType Leaf) {
        $errorLogItem = Get-Item -LiteralPath $errorLogFile
        $newErrorLog = $null -eq $errorLogTimestampBefore -or
            $errorLogItem.LastWriteTimeUtc -gt $errorLogTimestampBefore
        if ($newErrorLog) {
            $errorLogContent = Get-Content -LiteralPath $errorLogFile -Raw
            $logSections.Add("`r`n===== NEW ERRORLOG.TXT =====`r`n$errorLogContent")
        }
    }

    $combinedOutput = "$standardOutput`r`n$standardError"
    $errorPattern = '(?m)^\*\*\*|Bad conversion of parameter|While processing line|Traceback \(most recent call last\)|Unhandled exception|No licenses found'
    $consoleError = [regex]::IsMatch($combinedOutput, $errorPattern)

    $statusCode = 0
    $status = 'success'
    if ($licenseUnavailable) {
        $statusCode = 3
        $status = 'license-unavailable'
    }
    elseif ($timedOut) {
        $statusCode = 124
        $status = 'timeout'
    }
    elseif ($null -ne $processExitCode -and $processExitCode -ne 0) {
        $statusCode = $processExitCode
        $status = 'process-error'
    }
    elseif ($consoleError -or $newErrorLog) {
        $statusCode = 1
        $status = '3dec-error'
    }

    [IO.File]::WriteAllText(
        $resolvedLogFile,
        ($logSections -join "`r`n"),
        [Text.UTF8Encoding]::new($false)
    )

    if ($EchoOutput) {
        Write-Output $combinedOutput.TrimEnd()
    }
    elseif ($statusCode -ne 0) {
        Get-Content -LiteralPath $resolvedLogFile -Tail 80
    }

    $result = [ordered]@{
        status = $status
        status_code = $statusCode
        timed_out = $timedOut
        license_unavailable = $licenseUnavailable
        action_required = if ($licenseUnavailable) {
            $licenseGuidance
        }
        else {
            $null
        }
        process_exit_code = $processExitCode
        executable = $resolvedExecutable
        data_file = $mainDataFile
        working_directory = $resolvedWorkingDirectory
        log_file = $resolvedLogFile
        duration_seconds = [Math]::Round(((Get-Date) - $startedAt).TotalSeconds, 3)
    }
    Write-Output ($result | ConvertTo-Json -Compress)
    exit $statusCode
}
finally {
    Remove-Item -LiteralPath $exitDataFile -Force -ErrorAction SilentlyContinue
}
