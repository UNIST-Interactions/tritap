TriTap

This project contains modified android kernel source code for the Sony SmartWatch3:
https://en.wikipedia.org/wiki/Sony_SmartWatch 

The modifications alter the touchscreen driver so that it logs the raw capacitive image to a proc file that is accessible to regular apps running on the phone. 

This project includes:

BatteryFace: 
A processing watch face that includes battery % in the top right corner.
Can only be installed via the phone hosting the smartwatch (over bluetooth).
Needs processing 3.2.3 (or similar).  

sw3Kernel: 
Kernels for the Sony SW3. Only works with version LCA43 (go to settings->about->build number to find your build number)
If you have another OS version, you can manually install LCA43 on your watch, see here:
https://forum.xda-developers.com/smartwatch-3/orig-development/rom-sony-smartwatch-3-rom-t3367728
This folder also includes a 1) touchimage kernel (that reports debug info) and standard kernel (that reports regular touch events). 
It also includes scripts to load kernels and a set of useful adb commands to use when the touchscreen is deactivated. 

touchImageMoments:
Processing lib that gets touch image data from the kernel. You will need install this. 

touchImagePC:
PC app to launch and communicate with the SW3. 
Communication requires that the SW3 and PC are connected to the same local WiFI router
Some settings (e.g. data mappings, etc) can be customized live. 

touchImageWatch:
Demo watch app showing touch image on SW3. Can communicate with PC if connected via WiFI. 

Kernel Mods:
The modified source files from the android kernel. The kernel we use is:
https://forum.xda-developers.com/smartwatch-3/orig-development/kernel-crpalmer-s-tetra-kernel-lca43-t3184872
All build info/files are on the github page for this project. Just swap in the files in this folder. 
