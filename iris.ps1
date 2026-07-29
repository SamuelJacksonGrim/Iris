<#
  Iris - a small, dependency-free screen capture tool.
  Phase 1: Screenshot (region drag, like the Snip tool). Record is Phase 2.

  Runs at the shell's own integrity level, so launched elevated it captures
  elevated windows fine - no UIPI wall, no third-party program, no upload path.

  The window hides itself before every capture, so Iris never appears in its
  own screenshot. Eventually this becomes the "eye" that feeds ProjectSynapse.

  Polish: global hotkey (Ctrl+Alt+S), tray icon, minimize-to-tray, live size
  readout, Esc-to-cancel.

  Built for Samuel.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
try {
  Add-Type -Namespace Win -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction Stop
  [Win.Dpi]::SetProcessDPIAware() | Out-Null
} catch {}

# Global-hotkey helper: a hidden native window that raises an event on WM_HOTKEY.
Add-Type -ReferencedAssemblies 'System.Windows.Forms' -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;
public class IrisHotKey : NativeWindow, IDisposable {
  [DllImport("user32.dll")] static extern bool RegisterHotKey(IntPtr hWnd, int id, uint fsModifiers, uint vk);
  [DllImport("user32.dll")] static extern bool UnregisterHotKey(IntPtr hWnd, int id);
  const int WM_HOTKEY = 0x0312;
  const int ID = 0x1A15;
  public event EventHandler Pressed;
  public IrisHotKey() { CreateHandle(new CreateParams()); }
  public bool Register(uint mod, uint vk) { return RegisterHotKey(this.Handle, ID, mod, vk); }
  protected override void WndProc(ref Message m) {
    if (m.Msg == WM_HOTKEY && Pressed != null) Pressed(this, EventArgs.Empty);
    base.WndProc(ref m);
  }
  public void Dispose() { UnregisterHotKey(this.Handle, ID); this.DestroyHandle(); }
}
'@

# For dependency-free animated-GIF encoding (WPF) + GDI handle cleanup.
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -Namespace Win -Name Gdi -MemberDefinition '[DllImport("gdi32.dll")] public static extern bool DeleteObject(IntPtr o);'

[System.Windows.Forms.Application]::EnableVisualStyles()

$OutDir = "$env:USERPROFILE\Pictures\Screenshots"

# --- interactive region selector: dim overlay, drag a rectangle, Esc cancels ---
function Get-RegionRect {
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $script:sel   = New-Object System.Drawing.Rectangle 0,0,0,0
  $script:start = $null

  $f = New-Object System.Windows.Forms.Form
  $f.FormBorderStyle = 'None'; $f.StartPosition = 'Manual'; $f.Bounds = $vs
  $f.TopMost = $true; $f.Opacity = 0.25; $f.BackColor = 'Black'
  $f.Cursor = [System.Windows.Forms.Cursors]::Cross; $f.KeyPreview = $true

  $f.Add_MouseDown({ $script:start = $_.Location })
  $f.Add_MouseMove({
    if ($script:start) {
      $x = [Math]::Min($script:start.X, $_.X); $y = [Math]::Min($script:start.Y, $_.Y)
      $w = [Math]::Abs($_.X - $script:start.X); $h = [Math]::Abs($_.Y - $script:start.Y)
      $script:sel = New-Object System.Drawing.Rectangle $x,$y,$w,$h
      $f.Invalidate()
    }
  })
  $f.Add_Paint({
    if ($script:sel.Width -gt 0) {
      $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::White), 1
      $_.Graphics.DrawRectangle($pen, $script:sel); $pen.Dispose()
      $txt = "{0} x {1}" -f $script:sel.Width, $script:sel.Height
      $font = New-Object System.Drawing.Font 'Consolas', 10
      $ty = [Math]::Max(0, $script:sel.Y - 18)
      $_.Graphics.DrawString($txt, $font, [System.Drawing.Brushes]::White, [single]$script:sel.X, [single]$ty)
      $font.Dispose()
    }
  })
  $f.Add_MouseUp({ $f.Close() })
  $f.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { $script:sel = New-Object System.Drawing.Rectangle 0,0,0,0; $f.Close() } })

  [void]$f.ShowDialog()
  $f.Dispose()

  if ($script:sel.Width -lt 2 -or $script:sel.Height -lt 2) { return $null }
  return (New-Object System.Drawing.Rectangle ($vs.X + $script:sel.X), ($vs.Y + $script:sel.Y), $script:sel.Width, $script:sel.Height)
}

function Invoke-CaptureRect {
  param($rect)
  $bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($rect.Location, [System.Drawing.Point]::Empty, $rect.Size)
  $g.Dispose()
  [System.Windows.Forms.Clipboard]::SetImage($bmp)
  if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
  $path = Join-Path $OutDir ("shot-{0:yyyyMMdd-HHmmss}.png" -f (Get-Date))
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  return $path
}

# One entry point used by the button, the tray, and the global hotkey.
function Invoke-Shot {
  $wasVisible = $script:main.Visible
  $script:main.Hide()
  Start-Sleep -Milliseconds 180
  [System.Windows.Forms.Application]::DoEvents()
  $rect = Get-RegionRect
  if ($rect) {
    $p = Invoke-CaptureRect $rect
    $script:status.Text = 'Saved: ' + (Split-Path $p -Leaf) + '   (also on clipboard)'
  } else {
    $script:status.Text = 'Cancelled - no region selected.'
  }
  if ($wasVisible) { $script:main.Show(); $script:main.Activate() }
}

# --- animated GIF (dependency-free): encode frames, patch per-frame delay + loop ---
function Patch-GifTiming([byte[]]$b, [int]$delayCs) {
  for ($i = 0; $i -lt $b.Length - 8; $i++) {
    if ($b[$i] -eq 0x21 -and $b[$i+1] -eq 0xF9 -and $b[$i+2] -eq 0x04) {
      $b[$i+4] = [byte]($delayCs -band 0xFF)
      $b[$i+5] = [byte](([int]$delayCs -shr 8) -band 0xFF)
    }
  }
  $has = $false
  for ($i = 0; $i -lt $b.Length - 11; $i++) {
    if ($b[$i] -eq 0x4E -and $b[$i+1] -eq 0x45 -and $b[$i+2] -eq 0x54 -and $b[$i+3] -eq 0x53 -and $b[$i+4] -eq 0x43) { $has = $true; break }
  }
  if ($has) { return ,$b }
  $packed = $b[10]; $gctSize = 0
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
}

function Stop-Recording {
  if (-not $script:recording) { return }
  $script:recording = $false
  if ($script:recTimer) { $script:recTimer.Stop(); $script:recTimer.Dispose(); $script:recTimer = $null }
  $count = 0; if ($script:frames) { $count = $script:frames.Count }
  if ($script:recBar) { $script:recBar.Close(); $script:recBar.Dispose(); $script:recBar = $null }
  $script:status.Text = "Encoding $count frames..."
  [System.Windows.Forms.Application]::DoEvents()
  if ($count -gt 0) {
    if (-not (Test-Path $script:OutDir)) { New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null }
    $path = Join-Path $script:OutDir ("rec-{0:yyyyMMdd-HHmmss}.gif" -f (Get-Date))
    try { Save-Gif $script:frames 10 $path; $script:status.Text = "Saved: $(Split-Path $path -Leaf)  ($count frames)" }
    catch { $script:status.Text = "Encode failed: $($_.Exception.Message)" }
  } else { $script:status.Text = 'Recording cancelled - no frames.' }
  if ($script:frames) { foreach ($f in $script:frames) { $f.Dispose() }; $script:frames = $null }
  $script:main.Show(); $script:main.Activate()
}

function Start-Recording {
  if ($script:recording) { Stop-Recording; return }
  $script:main.Hide()
  Start-Sleep -Milliseconds 180
  [System.Windows.Forms.Application]::DoEvents()
  $rect = Get-RegionRect
  if (-not $rect) { $script:status.Text = 'Recording cancelled.'; $script:main.Show(); return }
  $script:recRect = $rect
  $script:frames = New-Object System.Collections.Generic.List[System.Drawing.Bitmap]
  $script:recStart = [datetime]::Now
  $script:recording = $true

  # floating Stop bar, placed just OUTSIDE the region so it isn't filmed
  $bar = New-Object System.Windows.Forms.Form
  $bar.FormBorderStyle = 'None'; $bar.TopMost = $true; $bar.ShowInTaskbar = $false
  $bar.BackColor = [System.Drawing.Color]::FromArgb(20,20,26)
  $bar.Size = New-Object System.Drawing.Size 200,36
  $bar.StartPosition = 'Manual'; $bar.KeyPreview = $true
  $bx = $rect.X; $by = $rect.Y - 42
  if ($by -lt 2) { $by = $rect.Y + $rect.Height + 6 }
  $bar.Location = New-Object System.Drawing.Point $bx, $by

  $lbl = New-Object System.Windows.Forms.Label
  $lbl.AutoSize = $false; $lbl.Size = New-Object System.Drawing.Size 108,36
  $lbl.Location = New-Object System.Drawing.Point 8,0; $lbl.TextAlign = 'MiddleLeft'
  $lbl.ForeColor = [System.Drawing.Color]::FromArgb(232,84,104)
  $lbl.Font = New-Object System.Drawing.Font 'Segoe UI',9,([System.Drawing.FontStyle]::Bold)
  $lbl.Text = 'REC  0.0s'
  $bar.Controls.Add($lbl); $script:recLabel = $lbl

  $stop = New-Object System.Windows.Forms.Button
  $stop.Text = 'Stop'; $stop.Size = New-Object System.Drawing.Size 78,28
  $stop.Location = New-Object System.Drawing.Point 116,4
  $stop.FlatStyle = 'Flat'; $stop.ForeColor = 'White'; $stop.BackColor = [System.Drawing.Color]::FromArgb(150,40,54)
  $stop.Add_Click({ Stop-Recording })
  $bar.Controls.Add($stop)
  $bar.Add_KeyDown({ if ($_.KeyCode -eq 'Escape') { Stop-Recording } })
  $bar.Show(); $script:recBar = $bar

  $t = New-Object System.Windows.Forms.Timer
  $t.Interval = 100
  $t.Add_Tick({
    if (-not $script:recording) { return }
    try {
      $r = $script:recRect
      $fb = New-Object System.Drawing.Bitmap($r.Width, $r.Height)
      $fg = [System.Drawing.Graphics]::FromImage($fb)
      $fg.CopyFromScreen($r.Location, [System.Drawing.Point]::Empty, $r.Size)
      $fg.Dispose()
      $script:frames.Add($fb)
      $el = ([datetime]::Now - $script:recStart).TotalSeconds
      if ($script:recLabel) { $script:recLabel.Text = ('REC  {0:0.0}s  ({1}f)' -f $el, $script:frames.Count) }
      if ($script:frames.Count -ge 300) { Stop-Recording }
    } catch {}
  })
  $t.Start(); $script:recTimer = $t
}

# --- main window ---
$script:main = New-Object System.Windows.Forms.Form
$main = $script:main
$main.Text = 'Iris'
$main.ClientSize = New-Object System.Drawing.Size 300,190
$main.StartPosition = 'CenterScreen'
$main.FormBorderStyle = 'FixedSingle'
$main.MaximizeBox = $false
$main.BackColor = [System.Drawing.Color]::FromArgb(24,24,28)

$title = New-Object System.Windows.Forms.Label
$title.Text = 'Iris'
$title.ForeColor = [System.Drawing.Color]::FromArgb(120,200,255)
$title.Font = New-Object System.Drawing.Font 'Segoe UI',16,([System.Drawing.FontStyle]::Bold)
$title.AutoSize = $true; $title.Location = New-Object System.Drawing.Point 16,12
$main.Controls.Add($title)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = 'the eye'
$sub.ForeColor = [System.Drawing.Color]::FromArgb(90,90,100)
$sub.Font = New-Object System.Drawing.Font 'Segoe UI',8,([System.Drawing.FontStyle]::Italic)
$sub.AutoSize = $true; $sub.Location = New-Object System.Drawing.Point 60,22
$main.Controls.Add($sub)

$btnShot = New-Object System.Windows.Forms.Button
$btnShot.Text = 'Screenshot'
$btnShot.Size = New-Object System.Drawing.Size 260,44
$btnShot.Location = New-Object System.Drawing.Point 20,52
$btnShot.FlatStyle = 'Flat'; $btnShot.ForeColor = 'White'
$btnShot.Font = New-Object System.Drawing.Font 'Segoe UI',11
$btnShot.BackColor = [System.Drawing.Color]::FromArgb(40,44,54)
$main.Controls.Add($btnShot)

$btnRec = New-Object System.Windows.Forms.Button
$btnRec.Text = 'Record  (GIF)'
$btnRec.Size = New-Object System.Drawing.Size 260,38
$btnRec.Location = New-Object System.Drawing.Point 20,102
$btnRec.FlatStyle = 'Flat'; $btnRec.ForeColor = 'White'
$btnRec.Font = New-Object System.Drawing.Font 'Segoe UI',10
$btnRec.BackColor = [System.Drawing.Color]::FromArgb(74,40,48)
$main.Controls.Add($btnRec)

$script:status = New-Object System.Windows.Forms.Label
$status = $script:status
$status.AutoSize = $false; $status.Size = New-Object System.Drawing.Size 264,40
$status.Location = New-Object System.Drawing.Point 20,146
$status.Font = New-Object System.Drawing.Font 'Segoe UI',8
$status.ForeColor = [System.Drawing.Color]::FromArgb(140,140,150)
$main.Controls.Add($status)

# --- tray icon ---
$IconPath = Join-Path $PSScriptRoot 'iris.ico'
if (Test-Path $IconPath) { $irisIcon = New-Object System.Drawing.Icon $IconPath } else { $irisIcon = [System.Drawing.SystemIcons]::Application }
$main.Icon = $irisIcon

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = $irisIcon
$tray.Text = 'Iris - the eye'
$tray.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miShot = $menu.Items.Add('Screenshot  (Ctrl+Alt+S)')
$miShow = $menu.Items.Add('Show Iris')
$menu.Items.Add('-') | Out-Null
$miExit = $menu.Items.Add('Exit')
$tray.ContextMenuStrip = $menu

$miShot.Add_Click({ Invoke-Shot })
$miShow.Add_Click({ $main.Show(); $main.WindowState = 'Normal'; $main.Activate() })
$miExit.Add_Click({ $tray.Visible = $false; $main.Close() })
$tray.Add_MouseDoubleClick({ Invoke-Shot })

# --- global hotkey: Ctrl+Alt+S  (MOD_ALT=0x1, MOD_CONTROL=0x2, VK 'S'=0x53) ---
$hk = New-Object IrisHotKey
$hk.add_Pressed({ Invoke-Shot })
$hotOk = $hk.Register(([uint32]0x1 -bor [uint32]0x2), [uint32]0x53)
if ($hotOk) {
  $status.Text = "Ready.  Ctrl+Alt+S to snap from anywhere."
} else {
  $status.Text = "Ready.  (Ctrl+Alt+S was taken - use the button.)"
}

# --- behaviours ---
$btnShot.Add_Click({ Invoke-Shot })
$btnRec.Add_Click({ Start-Recording })

# Minimize hides to tray instead of the taskbar.
$balloonShown = $false
$main.Add_Resize({
  if ($main.WindowState -eq 'Minimized') {
    $main.Hide()
    if (-not $script:balloonShown) {
      $tray.ShowBalloonTip(1500, 'Iris', 'Still here in the tray. Ctrl+Alt+S to snap.', [System.Windows.Forms.ToolTipIcon]::Info)
      $script:balloonShown = $true
    }
  }
})

# Clean up on exit.
$main.Add_FormClosing({
  try { $hk.Dispose() } catch {}
  $tray.Visible = $false
  $tray.Dispose()
})

[void][System.Windows.Forms.Application]::Run($main)
