#!/bin/sh
 
echo "Loading regular touch screen kernel"

adb reboot bootloader

sleep 10s

fastboot boot ./regularTouchScreen.img