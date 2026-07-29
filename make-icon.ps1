<#
  make-icon.ps1 - draws the Iris icon (drooped rose + gentle eye) with GDI+ and
  exports a multi-size iris.ico plus a 256px preview PNG. No dependencies.

  Concept (Samuel's): stem from bottom-left, rose head drooped/bowed at top
  looking down, a soft non-eerie eye in the bottom-right empty space.
#>
param([string]$OutDir = 'C:\Users\spamw\tools\Iris')
Add-Type -AssemblyName System.Drawing

function Draw-Icon {
  param([System.Drawing.Graphics]$g)
  $g.SmoothingMode     = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $g.PixelOffsetMode   = 'HighQuality'

  $green  = [System.Drawing.Color]::FromArgb(47,125,52)
  $greenD = [System.Drawing.Color]::FromArgb(31,87,34)
  $roseD  = [System.Drawing.Color]::FromArgb(142,26,46)
  $roseM  = [System.Drawing.Color]::FromArgb(192,42,68)
  $roseL  = [System.Drawing.Color]::FromArgb(224,84,107)
  $ink    = [System.Drawing.Color]::FromArgb(44,35,32)
  $sclera = [System.Drawing.Color]::FromArgb(245,242,236)
  $irisC  = [System.Drawing.Color]::FromArgb(185,119,46)
  $irisD  = [System.Drawing.Color]::FromArgb(138,86,32)

  # --- STEM: bottom-left up, then hooking over the top so the head nods down ---
  $stem = New-Object System.Drawing.Drawing2D.GraphicsPath
  $stem.AddBezier(36,248, 48,186, 66,150, 90,126)
  $stem.AddBezier(90,126, 108,112, 126,114, 144,114)
  $penStem = New-Object System.Drawing.Pen $green, 11
  $penStem.StartCap = 'Round'; $penStem.EndCap = 'Round'; $penStem.LineJoin = 'Round'
  $g.DrawPath($penStem, $stem)

  # leaf on the stem
  $leaf = New-Object System.Drawing.Drawing2D.GraphicsPath
  $leaf.AddBezier(66,170, 94,150, 124,156, 120,184)
  $leaf.AddBezier(120,184, 94,192, 74,190, 66,170)
  $g.FillPath((New-Object System.Drawing.SolidBrush $green), $leaf)
  $g.DrawPath((New-Object System.Drawing.Pen $greenD, 2), $leaf)

  # --- ROSE HEAD: drooped, tilted toward the eye (bowed head, nodding down) ---
  $st = $g.Save()
  $g.TranslateTransform(132,104)
  $g.RotateTransform(46)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $roseM), -50,-42, 100,84)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $roseL), -38,-2, 76,44)
  # spiral bud (darker)
  $spiral = New-Object System.Drawing.Drawing2D.GraphicsPath
  $pts = New-Object System.Collections.Generic.List[System.Drawing.PointF]
  for ($t = 0.0; $t -lt 12.0; $t += 0.3) {
    $r = 3.1 * $t
    $pts.Add((New-Object System.Drawing.PointF ([single]([Math]::Cos($t)*$r)), ([single]([Math]::Sin($t)*$r))))
  }
  $spiral.AddLines($pts.ToArray())
  $penSp = New-Object System.Drawing.Pen $roseD, 4; $penSp.LineJoin = 'Round'
  $g.DrawPath($penSp, $spiral)
  $penEdge = New-Object System.Drawing.Pen $roseD, 2.5
  $g.DrawArc($penEdge, -46,-40, 92,80, 150, 170)
  $g.Restore($st)

  # --- EYE: bottom-right, gentle, glancing up toward the rose ---
  $eye = New-Object System.Drawing.Drawing2D.GraphicsPath
  $eye.AddBezier(146,188, 168,160, 204,160, 226,188)
  $eye.AddBezier(226,188, 204,214, 168,214, 146,188)
  $g.FillPath((New-Object System.Drawing.SolidBrush $sclera), $eye)

  $st2 = $g.Save()
  $g.SetClip($eye)
  $ix = 178.0; $iy = 183.0
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $irisC), $ix-20, $iy-20, 40, 40)
  $g.DrawEllipse((New-Object System.Drawing.Pen $irisD, 2), $ix-20, $iy-20, 40, 40)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush $ink), $ix-9, $iy-9, 18, 18)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)), $ix-6, $iy-8, 6, 6)
  $g.Restore($st2)

  $penEye = New-Object System.Drawing.Pen $ink, 3.5
  $penEye.StartCap = 'Round'; $penEye.EndCap = 'Round'
  $lidT = New-Object System.Drawing.Drawing2D.GraphicsPath
  $lidT.AddBezier(146,188, 168,160, 204,160, 226,188)
  $g.DrawPath($penEye, $lidT)
  $lidB = New-Object System.Drawing.Drawing2D.GraphicsPath
  $lidB.AddBezier(146,188, 168,214, 204,214, 226,188)
  $g.DrawPath((New-Object System.Drawing.Pen $ink, 2), $lidB)
}

function Render-Size([int]$size) {
  $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.Clear([System.Drawing.Color]::Transparent)
  $s = $size / 256.0
  $g.ScaleTransform($s, $s)
  Draw-Icon $g
  $g.Dispose()
  return $bmp
}

function Png-Bytes([System.Drawing.Bitmap]$bmp) {
  $ms = New-Object System.IO.MemoryStream
  $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  return $ms.ToArray()
}

# Classic 32bpp BMP/DIB frame (XOR pixels + empty AND mask) - renders in the tray,
# titlebar and shortcuts, unlike PNG-compressed frames.
function Dib-Bytes([System.Drawing.Bitmap]$bmp) {
  $w = $bmp.Width; $h = $bmp.Height
  $rect = New-Object System.Drawing.Rectangle 0,0,$w,$h
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $buf = New-Object byte[] ($stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $buf, 0, $buf.Length)
  $bmp.UnlockBits($data)

  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter $ms
  # BITMAPINFOHEADER (height doubled for XOR+AND)
  $bw.Write([uint32]40); $bw.Write([int32]$w); $bw.Write([int32]($h * 2))
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]0); $bw.Write([uint32]0)
  $bw.Write([int32]0); $bw.Write([int32]0); $bw.Write([uint32]0); $bw.Write([uint32]0)
  # XOR color data, bottom-up
  for ($y = $h - 1; $y -ge 0; $y--) { $bw.Write($buf, $y * $stride, $w * 4) }
  # AND mask, all zero (alpha handles transparency), bottom-up
  $maskRow = [int]([Math]::Floor(($w + 31) / 32) * 4)
  $zero = New-Object byte[] $maskRow
  for ($y = 0; $y -lt $h; $y++) { $bw.Write($zero, 0, $maskRow) }
  $bw.Flush()
  return ,$ms.ToArray()   # unary comma: keep it a single byte[], don't let PS unroll it
}

$sizes = 16,24,32,48,64,128,256
$frames = @()
foreach ($sz in $sizes) {
  $b = Render-Size $sz
  if ($sz -eq 256) { [System.IO.File]::WriteAllBytes((Join-Path $OutDir 'iris-icon-256.png'), ([byte[]](Png-Bytes $b))) }
  $frames += ,@{ size = $sz; data = ([byte[]](Dib-Bytes $b)) }
  $b.Dispose()
}

# assemble multi-size .ico with classic BMP frames
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter $ms
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($f in $frames) {
  $w = if ($f.size -ge 256) { 0 } else { $f.size }
  $bw.Write([byte]$w); $bw.Write([byte]$w)
  $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]$f.data.Length)
  $bw.Write([uint32]$offset)
  $offset += $f.data.Length
}
foreach ($f in $frames) { $bw.Write([byte[]]$f.data, 0, ([byte[]]$f.data).Length) }
$bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $OutDir 'iris.ico'), $ms.ToArray())

Write-Output ("Wrote iris.ico ({0} BMP frames) and iris-icon-256.png to {1}" -f $frames.Count, $OutDir)
