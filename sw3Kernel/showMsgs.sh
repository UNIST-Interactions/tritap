#!/bin/sh
 
echo "Showing touch dmesg's from kernel"

adb shell dmesg | grep -i touch