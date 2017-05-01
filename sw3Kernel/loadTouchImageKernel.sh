#!/bin/sh
 
echo "Loading touch image kernel"

adb reboot bootloader

sleep 10s

fastboot boot ./touchImageKernel.img