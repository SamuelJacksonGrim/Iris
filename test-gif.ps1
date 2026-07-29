<#
  test-gif.ps1 - de-risk the dependency-free animated-GIF path in isolation.
  Encodes synthetic frames, patches per-frame delay + loop, then verifies:
   - the file decodes back to the right frame count
   - every Graphic Control Extension carries the intended delay
   - a NETSCAPE2.0 loop block is present
#>
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -Namespace Win -Name Gdi -MemberDefinition '[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);'

# Patch GifBitmapEncoder output: set every GCE delay (centiseconds) and insert a loop block.
function Patch-GifTiming([byte[]]$b, [int]$delayCs) {
  for ($i = 0; $i -lt $b.Length - 8; $i++) {
    if ($b[$i] -eq 0x21 -and $b[$i+1] -eq 0xF9 -and $b[$i+2] -eq 0x04) {
      $b[$i+4] = [byte]($delayCs -band 0xFF)
      $b[$i+5] = [byte](([int]$delayCs -shr 8) -band 0xFF)
    }
  }
  # already looping?
  $has = $false
  for ($i = 0; $i -lt $b.Length - 11; $i++) {
    if ($b[$i] -eq 0x4E -and $b[$i+1] -eq 0x45 -and $b[$i+2] -eq 0x54 -and $b[$i+3] -eq 0x53 -and $b[$i+4] -eq 0x43) { $has = $true; break }
  }
  if ($has) { return ,$b }
  # compute global color table size to know where to insert
  $packed = $b[10]
  $gctSize = 0
  if (($packed -band 0x80) -ne 0) { $gctSize = 3 * [math]::Pow(2, ($packed -band 0x07) + 1) }
  $insertAt = 13 + [int]$gctSize
  $loop = [byte[]](0x21,0xFF,0x0B,0x4E,0x45,0x54,0x53,0x43,0x41,0x50,0x45,0x32,0x2E,0x30,0x03,0x01,0x00,0x00,0x00)
  $out = New-Object byte[] ($b.Length + $loop.Length)
  [Array]::Copy($b, 0, $out, 0, $insertAt)
  [Array]::Copy($loop, 0, $out, $insertAt, $loop.Length)
  [Array]::Copy($b, $insertAt, $out, $insertAt + $loop.Length, $b.Length - $insertAt)
  return ,$out
}

function Save-Gif {
  param([System.Collections.Generic.List[System.Drawing.Bitmap]]$frames, [int]$delayCs, [string]$path)
  $enc = New-Object System.Windows.Media.Imaging.GifBitmapEncoder
  foreach ($bmp in $frames) {
    $h = $bmp.GetHbitmap()
    try {
      $src = [System.Windows.Interop.Imaging]::CreateBitmapSourceFromHBitmap($h, [IntPtr]::Zero, [System.Windows.Int32Rect]::Empty, [System.Windows.Media.Imaging.BitmapSizeOptions]::FromEmptyOptions())
      $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($src))
    } finally { [Win.Gdi]::DeleteObject($h) | Out-Null }
  }
  $ms = New-Object System.IO.MemoryStream
  $enc.Save($ms)
  $bytes = [byte[]](Patch-GifTiming ([byte[]]$ms.ToArray()) $delayCs)
  [System.IO.File]::WriteAllBytes($path, $bytes)
  return ,$bytes
}

# --- build 6 synthetic frames: a box sliding left->right ---
$frames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
for ($i = 0; $i -lt 6; $i++) {
  $bmp = New-Object System.Drawing.Bitmap 120, 60
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::FromArgb(20,20,28))
  $g.FillRectangle([System.Drawing.Brushes]::Crimson, (10 + $i*16), 18, 22, 22)
  $g.Dispose()
  $frames.Add($bmp)
}

$path = 'C:\Users\spamw\tools\Iris\test.gif'
$bytes = [byte[]](Save-Gif $frames 10 $path)   # 10 cs = 100ms = ~10fps
foreach ($f in $frames) { $f.Dispose() }

# --- verify ---
"File: $path  ($($bytes.Length) bytes)"
$dec = [System.Windows.Media.Imaging.GifBitmapDecoder]::new([uri]"file:///$($path -replace '\\','/')", [System.Windows.Media.Imaging.BitmapCreateOptions]::PreservePixelFormat, [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
"Decoded frame count: $($dec.Frames.Count)  (expected 6)"
$gce = 0; $delaysOk = 0
for ($i = 0; $i -lt $bytes.Length - 8; $i++) {
  if ($bytes[$i] -eq 0x21 -and $bytes[$i+1] -eq 0xF9 -and $bytes[$i+2] -eq 0x04) {
    $gce++
    $d = $bytes[$i+4] -bor ($bytes[$i+5] -shl 8)
    if ($d -eq 10) { $delaysOk++ }
  }
}
"GCE blocks found: $gce   with correct 10cs delay: $delaysOk"
$loop = $false
for ($i = 0; $i -lt $bytes.Length - 11; $i++) { if ($bytes[$i] -eq 0x4E -and $bytes[$i+1] -eq 0x45 -and $bytes[$i+2] -eq 0x54 -and $bytes[$i+3] -eq 0x53 -and $bytes[$i+4] -eq 0x43) { $loop = $true; break } }
"NETSCAPE loop block present: $loop"
if ($dec.Frames.Count -eq 6 -and $gce -ge 6 -and $delaysOk -ge 6 -and $loop) { "RESULT: PASS - timing + loop are correct" } else { "RESULT: NEEDS WORK" }