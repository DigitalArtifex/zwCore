#!/bin/sh
#
#    Minimalist shell script for headless setup of wireless on piCore
#  made specifically for the Raspberry Pi Zero W. By James Dudeck
#


WIRELESSMODULE="wireless-`uname -r`.tcz"
WIRELESSFIRMWARE="firmware-rpi-wifi.tcz"
SSID=""
PASS=""
MODE="dhcp"
IP=""
NETMASK=""
GATEWAY=""
NAMESERVER=""

MISSINGDEPLIST=""
HASMISSINGDEPS=0
DUMPDEPS=0

add_missing() {
	if [ ${#MISSINGDEPLIST} = 0 ]; then
		MISSINGDEPLIST="$1"
	else
		MISSINGDEPLIST="$MISSINGDEPLIST:$1"
	fi;
	
	HASMISSINGDEPS=1
}

while getopts a:p:m:d flag
do
    case "${flag}" in
        a) SSID=${OPTARG};;
        p) PASS=${OPTARG};;
        m) MODE=${OPTARG};;
        d) DUMPDEPS=1;;
    esac
done

DEPS=""
DEPS="$DEPS libnl.tcz"
DEPS="$DEPS ncurses.tcz"
DEPS="$DEPS readline.tcz"
DEPS="$DEPS iw.tcz"
DEPS="$DEPS ca-certificates.tcz"

if [ $DUMPDEPS = 1 ] ; then
	$DEPS="$DEPS openssl.tcz wireless_tools.tcz wpa_supplicant.tcz"
	
	echo $DEPS
	exit 0
fi

echo "Checking Environment.."

if ! test -f "../optional/$WIRELESSMODULE"; then
	add_missing "$WIRELESSMODULE"
fi

if ! test -f "../optional/$WIRELESSFIRMWARE"; then
	add_missing "$WIRELESSFIRMWARE"
fi

for DEP in ${DEPS}; do
    if ! test -f "../optional/$DEP"; then
		add_missing "$DEP"
    fi
done

if [ $HASMISSINGDEPS = 1 ]; then
	echo "Environment is missing dependencies."
	echo "Creating on-host list.."
	
	if ! test -d "onhost/"; then
		mkdir "onhost/"
	fi
	
	if ! test -f "onhost/wireless.lst"; then
		touch "onhost/wireless.lst"
		sleep 1
	fi
	
	echo "$MISSINGDEPLIST" > "onhost/wireless.lst"
	echo "Done"
	echo "Please run zwsetup-onhost.sh on a host machine with internet"
	exit 1
else
	echo "All dependencies found."
	echo ""
fi

echo "Loading Dependencies.."
for DEP in ${DEPS}; do
	tce-load -i $DEP
done

echo "Done."
echo ""
#This was the main issue. Almost every tutorial and onboot file I found
#  called for the firmware being loaded first, but the module has to be loaded first
echo "Loading Wifi Firmware.."
	tce-load -i $WIRELESSMODULE
	tce-load -i $WIRELESSFIRMWARE
echo "Done."
echo ""

echo "Loading Wifi Software.."
	tce-load -i openssl.tcz
	tce-load -i wireless_tools.tcz
	tce-load -i wpa_supplicant.tcz
echo "Done."
echo ""

#Taken from wifi.sh by Bela Markus
unset WIFI && CNT=0
until [ -n "$WIFI" ]
do
	[ $((CNT++)) -gt 10 ] && break || sleep 1
	WIFI="$(iwconfig 2>/dev/null | awk '{if (NR==1)print $1}')"
done
if [ -z "$WIFI" ]; then
	echo "No wifi devices found!"
	exit 1
fi
echo "--Found wifi device $WIFI"
#End Taken 

echo "Searching for tcedir/firstboot/ files"
TCEDIR="/etc/sysconfig/tcedir"
#wpa_supplicant.conf
if test -f "$TCEDIR/firstboot/wpa_supplicant.conf" ; then
	sudo mv "$TCEDIR/firstboot/wpa_supplicant.conf" /opt/wpa_supplicant.conf
	
	#plain text file that auto-destructs after configuring
	elif test -f "$TCEDIR/firstboot/wireless.conf" ; then
		sudo wpa_passphrase "$SSID" $PASS > /etc/wpa_supplicant.conf
		sudo rm "$TCEDIR/tcedir/firstboot/wireless.conf"
	else
	echo "Searching for configuration file.."
	if ! test -f /opt/wpa_supplicant.conf ; then
		echo "No configuration files found. Device will not be connected to an access point"
		exit 1
	fi
fi

sudo filetool.sh -b

echo "Attempting Auto Connect on $SSID.."
sudo ifconfig $WIFI up 2>/dev/null
sudo wpa_supplicant -B -c/opt/wpa_supplicant.conf -i$WIFI -Dwext >/dev/null 2>&1

if [ $MODE = "dhcp" ]; then
	sudo pkill udhcpc
	sudo udhcpc -b -i $WIFI -x hostname:box -p /var/run/udhcpc.$WIFI.pid
elif [ $MODE = "static" ]; then
	sudo ifconfig $WIFI $IP netmask $NETMASK up
	sudo iwconfig $WIFI essid $SSID key $PASS
	
else 
	echo "Incorrect configuration passed. $MODE is unknown"
	exit 1
fi
