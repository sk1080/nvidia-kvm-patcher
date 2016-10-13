# nvidia-kvm-patcher

### Quick Instructions

    1. Start NVIDIA Driver Setup, Exit Before Installing (Unpacks to C:/NVIDIA)
    2. Install the appropriate WDK/DDK, See OS Support
    3. If on Windows 7, See Windows 7 Workaround
    4. Enable Test Mode and Reboot
    5. Open powershell and run patcher.ps1 C:/NVIDIA/DisplayDriver/Version/Win10_64/International/Display.Driver
    6. Install Driver Through Extracted Installer (In C:/NVIDIA/DisplayDriver/Version)

### TLDR

So, so story so far:
You have a VM that uses a passed-through NVIDIA graphics card

However, the driver errored out with code 43, or outright blue-screened your VM

This is because NVIDIA "Introduced a Bug" making their driver "Fail" on "Unsupported configurations", such as having a geforce, by "accidentally" detecting the prescence of a hypervisor

Now, naturally, after some googling, you did something like this (libvirt config):
```xml
    <kvm>
      <hidden state='on'/>
    </kvm>
```

And this solves the problem, by masking off virtualization related CPUIDs/MSRs. However, this comes with the following issue:
Naturally, you can't use those virtualization extensions anymore, as the guest has no way of detecting them

Now, supposing we want these extensions enabled, we could be smart and do some magic down at the KVM level to detect when nvidia is probing and only feed it the BS. However, I am not smart, and therefore I am going to do something very dumb...

This script patches the NVIDIA driver to "fix the bug", and then attempts to test sign it

It is fugly, but has been tested to work on various NVIDIA drivers between 361.91 and 373.06

Use At Your Own Risk...

### Troubleshooting

1. If testsigning fails, make sure you are running Windows 10 x64, and have the WDK Installed
2. Windows will attempt to overwrite the driver using versions from windows update, you will want to blacklists these updates using Microsoft's tool: https://support.microsoft.com/en-us/kb/3073930
3. Having another problem? File an Issue. I would love some feedback on my crappy script.

### OS Support

* Windows 7 x64 is supported using the [Windows 7 DDK] (https://www.microsoft.com/en-us/download/details.aspx?id=11800)
* Windows 10 x64 is supported using the [Windows 10 WDK] (https://developer.microsoft.com/en-us/windows/hardware/windows-driver-kit)

### Windows 7 Workaround

For some reason, at least on the test system, signtool in the Windows 7 WDK Pre-Dates The Timestamp (possible reverse timezone compensation???). To get around this, remove all instances of the SKSoftware Certificate using mmc (if you have ran the script before), pre-date your clock by 2 days, and execute gencert.ps1 using powershell.

### Tested Host Platforms
* libvirtd 2.3.0 running qemu 2.6.50 using OVMF UEFI bios
* xen 4.7 using bios

### Tested Non-Working Host Platforms
* libvirtd 2.3.0 running qemu 2.6.50 using bios

