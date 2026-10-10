# Registers .photonamger files for the current Windows user (no administrator rights needed).
$ErrorActionPreference = 'Stop'
Write-Host 'Select the Archino executable (Archino.exe / fgphoto.exe).' -ForegroundColor Cyan
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.Title = 'انتخاب فایل اجرایی آرشینو'
$dialog.Filter = 'Executable (*.exe)|*.exe'
$dialog.Multiselect = $false
try { Add-Type -AssemblyName System.Windows.Forms } catch {}
if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
  Write-Host 'لغو شد.'
  exit 1
}
$exe = $dialog.FileName
$progId = 'Archino.Project'
$classes = 'HKCU:\Software\Classes'
New-Item -Path "$classes\.photonamger" -Force | Out-Null
Set-Item -Path "$classes\.photonamger" -Value $progId
New-Item -Path "$classes\$progId" -Force | Out-Null
Set-Item -Path "$classes\$progId" -Value 'Archino Project'
New-Item -Path "$classes\$progId\DefaultIcon" -Force | Out-Null
Set-Item -Path "$classes\$progId\DefaultIcon" -Value ('"{0}",0' -f $exe)
New-Item -Path "$classes\$progId\shell\open\command" -Force | Out-Null
Set-Item -Path "$classes\$progId\shell\open\command" -Value ('"{0}" "%1"' -f $exe)
# Refresh Explorer's file association cache if the Windows API is available.
try {
  Add-Type @'
using System;
using System.Runtime.InteropServices;
public class AssocRefresh {
  [DllImport("shell32.dll", CharSet=CharSet.Auto, SetLastError=true)]
  public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@
  [AssocRefresh]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
} catch {}
Write-Host ''
Write-Host 'انجام شد. از این پس با دوبار کلیک روی فایل .photonamger آرشینو اجرا و همان پروژه باز می‌شود.' -ForegroundColor Green
Write-Host ('Executable: ' + $exe)
Read-Host 'برای خروج Enter را بزنید'
