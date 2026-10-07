<#
  Builds the Android APK on this Windows machine.

  Why the workarounds: the project path contains an apostrophe and Turkish
  characters ("FURKAN'S PC", "Darbogazhesaplayıcı") and the user profile path
  contains a space. Android Gradle refuses non-ASCII project paths and Java
  cannot open its loopback socket from a temp dir with these characters.
  We therefore build from a subst drive (X:) and keep Gradle/temp files under
  C:\src. Moving the project to an ASCII-only path makes all of this optional.

  Usage:  powershell -ExecutionPolicy Bypass -File tool\build_android.ps1 [-Release]
#>
param([switch]$Release)

$ErrorActionPreference = 'Stop'
$project = Split-Path -Parent $PSScriptRoot
$drive = 'X:'

if (-not (Test-Path "$drive\app\pubspec.yaml")) {
  subst $drive $project
}
New-Item -ItemType Directory -Force C:\src\tmp | Out-Null

$env:TEMP = 'C:\src\tmp'
$env:TMP = 'C:\src\tmp'
$env:GRADLE_USER_HOME = 'C:\src\.gradle'
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:JAVA_TOOL_OPTIONS = '-Djava.io.tmpdir=C:\src\tmp -Djdk.net.unixdomain.tmpdir=C:\src\tmp'
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  $env:Path += ';C:\src\flutter\bin'
}

Push-Location "$drive\app"
try {
  if ($Release) {
    flutter build apk --release --obfuscate --split-debug-info=build\debug-info
  } else {
    flutter build apk --debug
  }
  if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
} finally {
  Pop-Location
}
