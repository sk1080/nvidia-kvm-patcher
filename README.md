# nvidia-kvm-patcher

So, so story so far:
You have a VM that uses a passed-through NVIDIA graphics card

However, the driver errored out with code 43, or outright blue-screened your VM

This is because NVIDIA "Introduced a Bug" making their driver "Fail" on "Unsupported configurations", such as having a geforce, by "accidentally" detecting the prescence of a hypervisor

Now, naturally, after some googling, you did something like this (libvirt config):
```xml
    <kvm>
      <hidden state='off'/>
    </kvm>
```
    
And this solves the problem, by masking off virtualization related CPUIDs/MSRs. However, this comes with the following issue:
Naturally, you can't use those virtualization extensions anymore, as the guest has no way of detecting them

Now, supposing we want these extensions enabled, we could be smart and do some magic down at the KVM level to detect when nvidia is probing and only feed it the BS. However, I am not smart, and therefore I am going to do something very dumb...

This script patches the NVIDIA driver to "fix the bug", and then attempts to test sign it (Only setup for Windows 10 x64 currently).

It is fugly, but has been tested to work on NVIDIA drivers 361.91 and 368.39...
For test signing to work without additional modification, one must be on Windows 10 x64, have the WDK installed, and run the script as an administrator.

Use At Your Own Risk...
