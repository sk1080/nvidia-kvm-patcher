param (
    [string]$directory = $pwd
)
$pwd = $directory

#Adapted from https://blogs.msdn.microsoft.com/virtual_pc_guy/2010/09/23/a-self-elevating-powershell-script/
# Get the ID and security principal of the current user account
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)

# Get the security principal for the Administrator role
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator

# Check to see if we are currently running "as Administrator"
if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   # We are running "as Administrator" - so change the title and background color to indicate this
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
   }
else
   {
   # We are not running "as Administrator" - so relaunch as administrator

   # Create a new process object that starts PowerShell
   $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";

   # Specify the current script path and name as a parameter
   [string[]]$argList = @('-ExecutionPolicy', 'Unrestricted')
   $argList += $myInvocation.MyCommand.Definition
   $argList += @('-directory', $pwd)
   $newProcess.Arguments = $argList

   # Indicate that the process should be elevated
   $newProcess.Verb = "runas";

   # Start the new process
   $process = [System.Diagnostics.Process]::Start($newProcess);
   $process.WaitForExit()

   # Exit from the current, unelevated, process
   exit
   }

$CertFile = Join-Path -Path $pwd -ChildPath "TestSign.cer"
Write-Host "Certificate Path: " $CertFile

#Check For Existence of Certificate In Root
$Certs = @(Get-ChildItem cert:\LocalMachine\Root | Where {$_.subject -eq 'CN=SKSoftware'})
if ($Certs.length -eq 0) {
    Write-Host "Cert Not Found in Root Store"

    #Not in Root, Check User
    $Certs = @(Get-ChildItem -recurse cert:\CurrentUser\ | Where {$_.subject -eq 'CN=SKSoftware'})
    if ($Certs.length -eq 0) {
        #No Certificate, Create a New One
        Write-Host "Certificate not Found in User Store, Creating"
        if (Get-Command New-SelfSignedCertificate -errorAction SilentlyContinue)
        {
            $Cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject CN=SKSoftware -CertStoreLocation "Cert:\CurrentUser\My"
        }
        else
        {
            Write-Host "New-SelfSignedCertificate Not Available, Falling Back To Makecert"
            
            $makecert = 'C:/WinDDK/7600.16385.1/bin/amd64/makecert.exe'
            if(-Not(Test-Path $makecert))
            {
                Write-Host "[!] Failure: Unable to find $installer_config"
                exit
            }
            
            & $makecert -r -pe -ss MY -n CN=SKSoftware -eku 1.3.6.1.5.5.7.3.3 $CertFile
            
        }
    }
    else
    {
        Write-Host "Certificate Found in User Store"
        $Cert = $Certs[0]
    }
    
    if (Get-Command Export-Certificate -errorAction SilentlyContinue)
    {
        $output = Export-Certificate -Cert $Cert -FilePath $CertFile -Type CERT
    }

    Write-Host "Adding Certificate to Root Store"
    $pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
    $pfx.import($CertFile)
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store(
        [System.Security.Cryptography.X509Certificates.StoreName]::Root,
        "localmachine"
    )
    $store.open("MaxAllowed")
    $store.add($pfx)
    $store.close()

}
else
{
    Write-Host "Certificate Found In Root Store"
    $Cert = $Certs[0]
}

if (Get-Command Export-Certificate -errorAction SilentlyContinue)
{
    $output = Export-Certificate -Cert $Cert -FilePath $CertFile -Type CERT
}