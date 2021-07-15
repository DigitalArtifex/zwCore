# zwCore
piCore specific scripts and configurations for the Raspberry Pi Zero W. The main purpose of these scripts is to provide an easy-to-use way to help automate the setup, maintain and configure Zero W's running piCore.

The main goal is to be able to automate the setup routine of a fresh image deployment, from a host machine. Simply supply a zwsetup.conf in tce/zwsetup/firstboot and include zwcore-alpha.tcz in the onboot.lst. The zwsetup.sh script will be automatically run, implement the configurations and zero-out the file's data to protect any plain-text passwords that may have been included. 

# Usage

