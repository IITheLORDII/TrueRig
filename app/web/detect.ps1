<#
  TrueRig donanim algilama araci
  - Sadece OKUR: islemci, ekran karti, RAM modulleri, anakart.
  - Hicbir sey yuklemez, ayar degistirmez, internete veri GONDERMEZ.
  - Bilgileri bir koda cevirir, panoya kopyalar ve TrueRig'i bu kodla acar.
    Kod adres cubugunun '#' kismindadir; tarayici bu kismi sunucuya iletmez.

  Kullanim: dosyaya sag tikla -> "PowerShell ile calistir"
            ya da: powershell -ExecutionPolicy Bypass -File detect.ps1 [-NoOpen]
#>
param(
  [string]$Site = 'https://truerig.app',
  [switch]$NoOpen,
  [switch]$Json
)

$ErrorActionPreference = 'Stop'

function Clean([string]$s) {
  if ($null -eq $s) { return $null }
  return ($s -replace '\s+', ' ').Trim()
}

$cpu   = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
$gpus  = @(Get-CimInstance -ClassName Win32_VideoController |
           ForEach-Object { Clean $_.Name } | Where-Object { $_ })
$ram   = @(Get-CimInstance -ClassName Win32_PhysicalMemory | ForEach-Object {
           [ordered]@{
             gb   = [int][math]::Round($_.Capacity / 1GB)
             mts  = [int]$(if ($_.ConfiguredClockSpeed) { $_.ConfiguredClockSpeed } else { $_.Speed })
             type = [int]$_.SMBIOSMemoryType
           } })
$board = Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -First 1

$report = [ordered]@{
  v       = 1
  cpu     = Clean $cpu.Name
  cores   = [int]$cpu.NumberOfCores
  threads = [int]$cpu.NumberOfLogicalProcessors
  gpus    = $gpus
  ram     = $ram
  board   = Clean ("{0} {1}" -f $board.Manufacturer, $board.Product)
}

$text = $report | ConvertTo-Json -Compress -Depth 4
if ($Json) { $text; return }

$code = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)).
          TrimEnd('=').Replace('+', '-').Replace('/', '_')

Write-Host ''
Write-Host 'Algilanan donanim:' -ForegroundColor Cyan
Write-Host ("  Islemci   : {0} ({1}C/{2}T)" -f $report.cpu, $report.cores, $report.threads)
$gpus | ForEach-Object { Write-Host "  Ekran k.  : $_" }
$total = ($ram | Measure-Object -Property gb -Sum).Sum
Write-Host ("  RAM       : {0} GB, {1} modul" -f $total, $ram.Count)
Write-Host ("  Anakart   : {0}" -f $report.board)
Write-Host ''

try { Set-Clipboard -Value $code; Write-Host 'Kod panoya kopyalandi.' -ForegroundColor Green }
catch { Write-Host 'Kod (kopyalayip siteye yapistirin):' -ForegroundColor Yellow }
Write-Host $code
Write-Host ''

if (-not $NoOpen) {
  Start-Process ("{0}/#/detect?hw={1}" -f $Site.TrimEnd('/'), $code)
}
