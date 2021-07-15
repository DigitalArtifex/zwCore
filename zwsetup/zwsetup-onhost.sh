#!/bin/sh
#
#    Minimalist shell script for headless setup of wireless, bluetooth
#  and other protocols on piCore.
#
#  Made specifically for the Raspberry Pi Zero W. By James Dudeck
#
#    Usage:
#  ./zwsetup.sh -a SSID_NAME -p SSID_PASS -m dhcp
#  ./zwsetup-wireless.sh -a SSID_NAME -p SSID_PASS -m static IP=192.168.10.6 NETMASK=255.255.0.0 GATEWAY=192.168.1.10 NAMESERVER=8.8.8.8
#

VER="13"
SKIPPED_MODULES=""
WIRELESS_FIRMWARE=""
BLUETOOTH_FIRMWARE=""
WIRELESS_MODULE=""
BLUETOOTH_MODULE=""
TCEDIR=".."
DEVICE=""

while getopts v:s:d:t: flag
do
    case "${flag}" in
        v) VER=${OPTARG};;
        s) SKIPPED_MODULES=${OPTARG};;
        t) TCEDIR=${OPTARG};;
        d) DEVICE=${OPTARG};;
    esac
done

VER="$VER.x"

case $VER in
	"13.x")
		WIRELESS_FIRMWARE="firmware-rpi-wifi.tcz"
		BLUETOOTH_FIRMWARE="firmware-rpi-bt.tcz"
		WIRELESS_MODULE="wireless-5.10.16-piCore.tcz"
		BLUETOOTH_MODULE="bluetooth-5.10.16-piCore.tcz"
	;;
	"12.x")
		WIRELESS_FIRMWARE="firmware-rpi-wifi.tcz"
		BLUETOOTH_FIRMWARE="firmware-rpi-bt.tcz"
		WIRELESS_MODULE="wireless-5.4.51-piCore.tcz"
		BLUETOOTH_MODULE="bluetooth-5.4.51-piCore.tcz"
	;;
	*)
		echo "Unsupported piCore Version: $VER"
		exit 1
	;;
esac

MIRROR="http://tinycorelinux.net/$VER/armv6/tcz"

WIRELESS_DEPS="$(sh ./zwsetup-wireless.sh -d)"
WIRELESS_DEPS="${WIRELESS_DEPS} ${WIRELESS_MODULE} ${WIRELESS_FIRMWARE}"

if ! test -d "$TCEDIR/optional" ; then
	mkdir "$TCEDIR/optional"
fi

MD5ERRORS=0
MD5ERROR_THRESHOLD=5

echo "Checking for missing dependencies.."
for DEP in ${WIRELESS_DEPS}; do
	#fetch package
	if ! test -f "$TCEDIR/optional/$DEP" ; then
		if wget -S --spider $MIRROR/$DEP 2>&1 | grep -q 'Remote file exists'; then
			wget "$MIRROR/$DEP" -O "$TCEDIR/optional/$DEP"
		fi
	fi;
	
	#fetch checksum
	if ! test -f "$TCEDIR/optional/$DEP.md5.txt" ; then
		if wget -S --spider $MIRROR/$DEP.md5.txt 2>&1 | grep -q 'Remote file exists'; then
			wget "$MIRROR/$DEP.md5.txt" -O "$TCEDIR/optional/$DEP.md5.txt"
		fi
	fi;
	
	#fetch dependency file
	if ! test -f "$TCEDIR/optional/$DEP.dep" ; then
		if wget -S --spider $MIRROR/$DEP.dep 2>&1 | grep -q 'Remote file exists'; then
			wget "$MIRROR/$DEP.dep" -O "$TCEDIR/optional/$DEP.dep"
		
			DEPFILE="$TCEDIR/optional/$DEP.dep"
			
			while INL= read -r DEPLINE
			do 
				WIRELESSDEPS="$WIRELESSDEPS $DEPLINE"
			done < "$DEPFILE"
		fi
	fi;
	
	#validate download
	CHECKSUM=$(md5sum $TCEDIR/optional/$DEP)
	FILESUM=$(cat $TCEDIR/optional/$DEP.md5.txt)
	if [ ${CHECKSUM%% *} != ${FILESUM%% *} ] ; then
		rm "$TCEDIR/optional/$DEP"
		rm "$TCEDIR/optional/$DEP.md5.txt"
		rm "$TCEDIR/optional/$DEP.dep"
		
		((MD5ERRORS=MD5ERRORS+1))
		
		if test $MD5ERRORS -eq $MD5ERROR_THRESHOLD ; then
			echo "Encountered $MD5ERRORS errornous downloads. Aborting."
			exit 1
		fi
		
		#add additional deps to the download queue
		WIRELESSDEPS="${WIRELESSDEPS} ${DEP}"
	fi
done

echo "All dependencies passed verification."
