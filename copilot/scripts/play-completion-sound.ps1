$ErrorActionPreference = 'SilentlyContinue'

try {
    Add-Type -AssemblyName PresentationCore

    $copilotHome = if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $env:USERPROFILE '.copilot' }
    $path = Join-Path $copilotHome 'sounds\success-achievement.mp3'
    if (-not (Test-Path $path)) { exit 0 }

    $player = New-Object System.Windows.Media.MediaPlayer
    $player.Open([Uri]::new($path))

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while (-not $player.NaturalDuration.HasTimeSpan -and $sw.ElapsedMilliseconds -lt 3000) {
        Start-Sleep -Milliseconds 50
    }

    if ($player.NaturalDuration.HasTimeSpan) {
        $ms = [int]$player.NaturalDuration.TimeSpan.TotalMilliseconds + 200
        $player.Play()
        Start-Sleep -Milliseconds $ms
        $player.Stop()
    }

    $player.Close()
}
catch {
    # silencioso de proposito: som nunca deve travar ou poluir o hook do Copilot
}

exit 0
