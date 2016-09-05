# Nvidia KVM Patcher
# SK1080
# License: Do whatever you want with this code
# Pardon my poor powershell skills

# Note: Only Tested on Versions 361.91, 368.39, and 372.54
# Note: Targeted at Windows 10 X64, Fix Tool Paths for Testsigning and /os: option in Inf2Cat to support other OS
# Note: Testsigning Requires Windows 10 WDK

param (
    [Parameter(Position=1)][string]$directory = ""
)

if($directory -eq "")
{
    Write-Host "Usage: patcher.ps1 [/path/to/Display.Driver]"
    exit
}

$sys_packed = Join-Path $directory "nvlddmkm.sy_"
$sys_unpacked = Join-Path $directory "nvlddmkm.sys"

if(-Not(Test-Path $sys_packed))
{
    Write-Host "[!] Failure: Unable to find nvlddmkm.sy_ in $directory"
    exit
}

Write-Host '[+] Unpacking nvlddmkm.sys'
iex "expand $sys_packed $sys_unpacked" | Out-Null

if(-Not(Test-Path $sys_unpacked))
{
    Write-Host "[!] Failure: Unable to unpack nvlddmkm.sys"
    exit
}

Write-Host '[+] Patching CPUID Check'
#Stupidity Incomming
$stream = New-Object IO.FileStream -ArgumentList $sys_unpacked, 'Open', 'Read'
$enc = [Text.Encoding]::GetEncoding(28591)
$sr = New-Object IO.StreamReader -ArgumentList $stream, $enc
$text = $sr.ReadToEnd()
$sr.close()
$stream.close()

$pattern = '\x48\x8D\x44\x24\x50\x4C\x8D\x4C\x24\x44\x45\x33\xC0\x48\x89\x44\x24\x30' # + 0x2B
$patch = [Byte[]]@(0x31, 0xC0, 0x90, 0x90, 0x90, 0x90, 0x90, 0x85, 0xC0)

$regex = [Regex]$pattern
$matches = $regex.Matches($text)
$count = $matches.Count
if($count -ne 1)
{
    Write-Host "[!] Failure: $count occurrences of patch pattern found"
    exit
}

$offset = $matches[0].Index + 0x2B

$stream = New-Object IO.FileStream -ArgumentList $sys_unpacked, 'Open', 'Write'
[void] $stream.Seek($offset, 'Begin')
$stream.Write($patch, 0, $patch.Length)

$stream.Close()

Write-Host '[+] Modifying Installer Config to Use Extracted Driver'
$installer_config = Join-Path $directory "DisplayDriver.nvi"
if(-Not(Test-Path $installer_config))
{
    Write-Host "[!] Failure: Unable to find $installer_config"
    exit
}

(Get-Content $installer_config) -replace 'nvlddmkm.sy_', 'nvlddmkm.sys' | Set-Content $installer_config

Write-Host '[+] Attempting to Test Sign Driver'

$inf2cat = 'C:/Program Files (x86)/Windows Kits/10/bin/x86/Inf2Cat.exe'
$signtool = 'C:/Program Files (x86)/Windows Kits/10/Tools/bin/i386/signtool.exe'

if(-Not(Test-Path $inf2cat))
{
    Write-Host "[!] Failure: Unable to find inf2cat at $inf2cat"
    exit
}
if(-Not(Test-Path $signtool))
{
    Write-Host "[!] Failure: Unable to find signtool at $signtool"
    exit
}

Write-Host '    [+] Generating Catalog File (this may take a while)'
& $inf2cat /driver:`"$directory`" /os:10_X64 | Out-Null

Write-Host '    [+] Generating and Installing Certificate'
$ScriptPath = Split-Path $MyInvocation.InvocationName
& (Join-Path $ScriptPath "gencert.ps1") -directory $ScriptPath | Out-Null

Write-Host '    [+] Signing Catalog File'

$catalog_path = $directory + './nv_disp.cat'
& $signtool sign /v /n SKSoftware /t http://timestamp.verisign.com/scripts/timstamp.dll $catalog_path