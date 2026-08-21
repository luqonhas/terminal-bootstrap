$ErrorActionPreference = 'SilentlyContinue'

try {
    Add-Type -AssemblyName PresentationCore

    $path = Join-Path $env:USERPROFILE '.claude\sounds\success-achievement.mp3'
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
    # silencioso de propósito: som nunca deve travar ou poluir o Stop hook
}

exit 0
