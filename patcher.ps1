# Nvidia KVM Patcher
# SK1080
# License: Do whatever you want with this code
# Use at your own risk!
# Pardon my poor powershell skills

# Note: Only Tested on Versions 361.91, 368.39, 372.54, and 419.67
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
$sys_packed_backup = Join-Path $directory "nvlddmkm.sy_.bak"
if(Test-Path $sys_packed)
{
    Move-Item $sys_packed $sys_packed_backup
}
$sys_packed = $sys_packed_backup

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

$pattern = '\xBB\x00\x00\x00\x40\x48\x8D\x44\x24\x50' # + 0x30
$patch = [Byte[]]@(0x31, 0xC0, 0x90, 0x90, 0x90, 0x90, 0x90, 0x85, 0xC0)

$regex = [Regex]$pattern
$matches = $regex.Matches($text)
$count = $matches.Count
if($count -ne 1)
{
    Write-Host "[!] Failure: $count occurrences of patch pattern found"
    exit
}

$offset = $matches[0].Index + 0x30

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

$inf2cat = ''
$signtool = ''

$inf2cat_paths = 'C:/Program Files (x86)/Windows Kits/10/bin/x86/Inf2Cat.exe', 'C:/Program Files (x86)/Windows Kits/10/bin/10.0.17763.0/x86/Inf2Cat.exe', 'C:/Program Files (x86)/Windows Kits/10/bin/10.0.17134.0/x86/Inf2Cat.exe', 'C:/WinDDK/7600.16385.1/bin/selfsign/Inf2Cat.exe'
$signtool_paths = 'C:/Program Files (x86)/Windows Kits/10/Tools/bin/i386/signtool.exe', 'C:/Program Files (x86)/Windows Kits/10/App Certification Kit/signtool.exe', 'C:/WinDDK/7600.16385.1/bin/amd64/signtool.exe'

foreach($path in $inf2cat_paths)
{
    if(Test-Path $path)
    {
        $inf2cat = $path
        break
    }
}

foreach($path in $signtool_paths)
{
    if(Test-Path $path)
    {
        $signtool = $path
        break
    }
}

if(-Not(Test-Path $inf2cat))
{
    Write-Host "[!] Failure: Unable to locate inf2cat, see/edit script for expected paths"
    exit
}
if(-Not(Test-Path $signtool))
{
    Write-Host "[!] Failure: Unable to locate signtool, see/edit script for expected paths"
    exit
}

$ostype = ''
$winver = [System.Environment]::OSVersion.Version
if($winver.Major -eq 6)
{
    if($winver.Minor -eq 1)
    {
        $ostype = '7_X64'
    }
    elseif($winver.Minor -eq 2 -Or $winver.Minor -eq 3)
    {
        $ostype = '8_X64'
    }
}
if($winver.Major -eq 10)
{
    $ostype = '10_X64'
}
if($ostype -eq '')
{
    Write-Host "[!] Failure: Unable to determine OS type, see script"
    exit    
}
Write-Host "    [+] Detected OS Type: $ostype"

Write-Host '    [+] Generating Catalog File (this may take a while, and sometimes you may have to press enter to get results)'
& $inf2cat /driver:`"$directory`" /os:$ostype | Out-Null

Write-Host '    [+] Generating and Installing Certificate'
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
& (Join-Path $ScriptPath "gencert.ps1") -directory $ScriptPath | Out-Null

Write-Host '    [+] Signing Catalog File'

$catalog_path = $directory + './nv_disp.cat'
& $signtool sign /v /n SKSoftware /t http://timestamp.verisign.com/scripts/timstamp.dll $catalog_path
& $signtool sign /v /n SKSOftware /t http://timestamp.verisign.com/scripts/timstamp.dll $sys_unpacked
