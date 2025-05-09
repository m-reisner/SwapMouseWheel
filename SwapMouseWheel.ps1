Clear-Host

# Self-elevating block
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "Adminrights needed. Try to get them." -ForegroundColor Red
    $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
    Start-Process pwsh.exe -Verb RunAs -ArgumentList $arguments
    Exit
}

Add-Type -AssemblyName PresentationFramework

# Clear all Variables
Get-Variable | Where-Object { -not $_.Options.ReadOnly -and $_.Name -notin @('args', 'null', 'true', 'false') } | ForEach-Object { Remove-Variable -Name $_.Name -Force -ErrorAction SilentlyContinue }

function Get-NamedXamlElements {
    param (
        [Parameter(Mandatory)]
        [xml]$XamlRaw,

        [Parameter(Mandatory)]
        [object]$RootElement
    )

    $elm = [PSCustomObject]@{}

    # Alle x:Name Attribute im XAML finden
    $names = Select-String -InputObject $XamlRaw.OuterXml -Pattern 'x:Name="([^"]+)"' -AllMatches |
        ForEach-Object { $_.Matches } |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique

    foreach ($name in $names) {
        $element = $RootElement.FindName($name)
        if ($element) {
            Add-Member -InputObject $elm -MemberType NoteProperty -Name $name -Value $element
        }
    }

    return $elm
}

function Set-ScrollDirection {
    param($ui)

    Write-Host "Searching for HID-Mices..." -ForegroundColor Cyan

    # Auswahl prüfen
    if (-not ($ui.rdb1.IsChecked -or $ui.rdb2.IsChecked)) {
        [System.Windows.MessageBox]::Show("You have to select a scrolldirection.", "Warning", "OK", "Warning")
        return
    }

    # Zielwert basierend auf Auswahl
    $newValue = if ($ui.rdb1.IsChecked) { 1 } else { 0 }

    # Alle HID-Mäuse durchsuchen
    $mouseKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\HID" -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "*Device Parameters" }

    foreach ($key in $mouseKeys) {
        try {
            # FlipFlopWheel-Wert setzen
            Set-ItemProperty -Path $key.PSPath -Name "FlipFlopWheel" -Value $newValue -ErrorAction Stop
            Write-Host "Scrolldirection set ($newValue) at: $key" -ForegroundColor Green
        } catch {
            Write-Host "Error on changing: $key" -ForegroundColor Red
        }
    }

    [System.Windows.MessageBox]::Show("Scrolldirection changed.`n`rMaybe you need a reboot or reconnecting the mouse.", "Success", "OK", "Information")
}


# XAML als String laden
[string]$xamlRaw = Get-Content "$PSScriptRoot\Window.xaml" -Raw
# Replace placeholder
$xamlRaw = $xamlRaw.Replace('[PSScriptRoot]', $PSScriptRoot)
[xml]$xaml = $xamlRaw
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)
# make names to elements auto-mode :)
$elm = Get-NamedXamlElements -XamlRaw $xaml -RootElement $window

$elm.btnApply.Add_Click({ Set-ScrollDirection -ui $elm })

# GUI erstellen
$window.ShowDialog() | Out-Null
