function Get-Tailor {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$Files,
        [switch]$Recurse,
        [switch]$Prefix, 
        [long]$Tail = 1
    )

    $colors = @("Yellow", "Cyan", "Magenta", "Green", "Blue")

    function Get-Settings {
        $localSettingsPath = "Tailor.json"
        $templateSettingsPath = "$env:SystemXInstallRepository\templates\Tailor.json"

        if (Test-Path $localSettingsPath) {
            return Get-Content $localSettingsPath | ConvertFrom-Json
        } elseif (Test-Path $templateSettingsPath) {
            return Get-Content $templateSettingsPath | ConvertFrom-Json
        } else {
            Write-Host "No Tailor.json found in local directory or template path."
            exit
        }
    }

    function highlight {
        Begin {
            $settings = Get-Settings
        }
        Process {
            $serviceName = (Split-Path $_.PSParentPath -Leaf)
            $serviceColor = $colors[([math]::Abs($serviceName.GetHashCode()) % $colors.Length)]

            if ($Prefix) {  # Check if the -Prefix switch is enabled
                Write-Host ("[$serviceName] " + $_.PSChildName) -NoNewline -ForegroundColor $serviceColor
            }

            $matched = $false

            foreach ($setting in $settings.rules) {
                if ($_ -match $setting.match) {
                    $matched = $true
                    Write-Host (" $_") -ForegroundColor $($setting.color)
                    break
                }
            }
            if (-not $matched -and $settings.default.enabled) {                
                    Write-Host (" $_") -ForegroundColor $($settings.default.color)
            }
        }
    }

    workflow Tailor {
        param (
            [string[]]$logFiles,
            [long]$Tail
        )
        foreach -parallel ($file in $logFiles) {
            Get-Content -wait -Tail $Tail $file 
        }
    }

    $ProgressPreference = 'SilentlyContinue'

    $expandedLogFiles = @()

    foreach ($file in $Files) {
        $fileItems = Get-ChildItem -Path $file -Recurse:$Recurse -File | Where-Object { Test-Path $_.FullName }
        $expandedLogFiles += $fileItems | Select-Object -ExpandProperty FullName
    }

    if ($expandedLogFiles.Count -gt 0) {
        tailor $expandedLogFiles $tail | highlight
    } else {
        Write-Host "No valid log files found."
    }
}

# Usage example
# Get-Tailor -files "C:\path\to\log1.log", "./log/*" -Recurse -Prefix