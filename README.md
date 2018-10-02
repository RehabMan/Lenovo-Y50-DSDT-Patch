## Lenovo Haswell Y50-70 patches by RehabMan

This set of patches/makefile can be used to patch your Lenovo Y50-70 DSDT/SSDTs.  There are also post install scripts that can be used to create and install the kexts the are required for this laptop series.

Although older versions of the repo had scripts to automate patching of DSDT/SSDTs, the current version does it all via config.plist hotpatching and SSDT-HACK.

Please refer to this guide thread on tonymacx86.com for a step-by-step process, feedback, and questions:

http://www.tonymacx86.com/yosemite-laptop-guides/165188-guide-lenovo-y50-y70-uhd-1080p-using-clover-uefi.html


### Change Log:

2018-09-02

- completed major changes for Mojave and use of AppleALC for audio


2015-11-12

- borrowed SSDT-HACK method from Lenovo u430 project

- disable EHCI#1 controller, use XHC only


2015-06-01 Initial Release

- initial creation using Lenovo u430 patches as a base


