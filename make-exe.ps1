<#
  make-exe.ps1 - compile Iris into a single self-contained .exe using the C#
  compiler already on the machine. Embeds iris.ps1 + iris.ico as resources and
  sets the rose as the exe's icon. Output: dist\Iris.exe (the only file to hand out).
#>
$dir  = 'C:\Users\spamw\tools\Iris'
$dist = Join-Path $dir 'dist'
New-Item -ItemType Directory -Path $dist -Force | Out-Null

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path $csc)) { throw "csc.exe not found - .NET Framework 4.x compiler missing." }

$out = Join-Path $dist 'Iris.exe'
Push-Location $dir
try {
  & $csc /nologo /target:winexe /win32icon:iris.ico "/out:$out" /resource:iris.ps1,iris.ps1 /resource:iris.ico,iris.ico Iris.cs
  $code = $LASTEXITCODE
} finally { Pop-Location }

if ($code -eq 0 -and (Test-Path $out)) {
  "OK: $out  ({0:N0} KB)" -f ((Get-Item $out).Length / 1KB)
} else {
  "BUILD FAILED (csc exit $code)"
}
