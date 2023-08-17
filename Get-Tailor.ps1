function Get-Tailor {
    param (
        [Parameter(Mandatory=$true)]
        [string[]]$Files,
        [switch]$Recurse,
        [switch]$Prefix,
        [switch]$Wait,
        [long]$Tail = 1,
        [string]$Settings
    )

    $colors = @("Yellow", "Cyan", "Magenta", "Green", "Blue")

    function Get-Settings {
        param (
            [string]$Settings  
        )
    
        $defaultSettings = "Tailor.json"
        
        if ($Settings) {
            if (Test-Path $Settings) {
                return Get-Content $Settings | ConvertFrom-Json
            } else {
                Write-Host "Custom settings file not found: $Settings"
                break
            }
        } elseif (Test-Path $defaultSettings) {
            return Get-Content $defaultSettings | ConvertFrom-Json
        } else {
            Write-Host "No Tailor.json found in local directory."
            break
        }
    }

    function highlight {
        Begin {
            $settings = Get-Settings -Settings $Settings
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
            [long]$Tail,
            [bool]$Wait
        )
        foreach -parallel ($file in $logFiles) {
            if ($Wait -eq $true) {  
                Get-Content -Wait -Tail $tail $file 
            } else {
                Get-Content -Tail $tail $file
            }
        }
    }

    $ProgressPreference = 'SilentlyContinue'

    $expandedLogFiles = @()

    foreach ($file in $Files) {
        $fileItems = Get-ChildItem -Path $file -Recurse:$Recurse -File | Where-Object { Test-Path $_.FullName }
        $expandedLogFiles += $fileItems | Select-Object -ExpandProperty FullName
    }

    if ($expandedLogFiles.Count -gt 0) {
        tailor $expandedLogFiles $Tail -Wait:$Wait| highlight
    } else {
        Write-Host "No valid log files found."
    }
}

# Usage example
# Get-Tailor -files "C:\path\to\log1.log", "./log/*" -Recurse -Prefix -Wait -Tail 10 -Settings "C:\scripts\mysettings.json"