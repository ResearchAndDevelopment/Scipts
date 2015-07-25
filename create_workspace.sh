#!/bin/bash
#============================
#You must be root to run this script
if [[ $EUID -ne 0 ]];then 
	verbose 0 "This script must be run as root" 
	exit 0
fi
#Variables
#DEBUG_LEVEL does what it sounds like. 0 is disabled and 5 most verbose
VERBOSE_VAL=5
WORKSPACE=workspace
BOOTLDR=bootldr
BOOTLDR_VER=v2015.07
BOOTLDR_URL=git://git.denx.de/u-boot.git
DEBUG=debug
IMAGES=images
PROJECT=project
ROOTFS=rootfs
ROOTFS_URL=https://rcn-ee.com/rootfs/eewiki/minfs/debian-8.1-minimal-armhf-2015-06-09.tar.xz
TMP=tmp
BUILDTOOLS=build-tools
DOC=doc
KERNEL=kernel
SYSAPPS=sysapps
TOOLS=tools
KERNEL_URL=https://github.com/RobertCNelson/bb-kernel
KENEL_VER=origin/am33x-v3.8
CC_URL=https://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
#CC_URL=PUT ADDRESS FOR ARAGO
WDIR=`pwd`
#receives two arguments Verbosity and message
#verbosity is betwen 0 lowest and 5 highest. 
verbose()
{
	if [[ $VERBOSE_VAL -ge $1 ]];then
		echo ${@:2} 
	fi	
}

prompt()
{
	read -t 20 -p "Enter $1 value or press enter for default \"$1\": " tmp
	if [[ $tmp ]];then
		echo $tmp 
	else	
		echo $1;
	fi	
}

WORKSPACE=$(prompt $WORKSPACE)
verbose 5 workspace is $WORKSPACE
mkdir -p $WORKSPACE
cd $WORKSPACE
mkdir -p $BOOTLDR $DEBUG $IMAGES $PROJECT $ROOTFS $TMP $BUILDTOOLS $DOC $KERNEL $SYSAPPS $TOOLS
#Prepare for downloading cross compiler
#for linaro you need 32 bit libraries
verbose 5 Installing 32 bit libraries for linaro
dpkg --add-architecture i386
apt-get update
apt-get install libc6:i386 libstdc++6:i386 libncurses5:i386 zlib1g:i386
#Download cross compiler tool
verbose 5 download cross compiler tools 
cd $WDIR/$WORKSPACE/$TOOLS
wget -c $CC_URL
verbose 5 extracting CC tools
tar xf gcc-linaro-arm-linux-*
verbose 5 Verifying Installed CC tools
#export CC=$WDIR/$WORKSPACE/$TOOLS/`ls -l| grep ^d | awk '{print $9}'`/bin/arm-linux-gnueabihf-
CC=$WDIR/$WORKSPACE/$TOOLS/`ls -l| grep ^d | awk '{print $9}'`/bin/arm-linux-gnueabihf-
if [[ $(${CC}gcc --version| grep -w  ^arm-linux-gnueabihf-gcc) ]];then
	verbose 5 CC installation succeeded 
else 
	verbose 0 CC installation failed
	exit 1
fi
#Download u-boot
verbose 5 downloading u-boot
cd $WDIR/$WORKSPACE/$BOOTLDR
git clone $BOOTLDR_URL
cd u-boot/
git checkout $BOOTLDR_VER -b tmp
verbose 5 Downloading patches to u-boot
wget -c https://rcn-ee.com/repos/git/u-boot-patches/v2015.07/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
verbose 5 applying patches to u-boot
patch -p1 < 0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
verbose 5 configuring and building u-boot
make ARCH=arm CROSS_COMPILE=${CC} distclean
make ARCH=arm CROSS_COMPILE=${CC} am335x_evm_defconfig
make ARCH=arm CROSS_COMPILE=${CC}
#Download kernel
verbose 5 downloading kernel from $KERNEL_URL
cd $WDIR/$WORKSPACE/$KERNEL
git clone $KERNEL_URL
verbose 5 Kernel is downloaded
cd bb-kernel/
verbose 5 checking out $KERNEL_VER
git checkout $KENEL_VER -b tmp
#Set CC for Kernel
verbose 5 configuring system variables
cp -v system.sh.sample system.sh
verbose 5 setting up CC path
verbose 5 comment out all the CCs
sed -i 's/^CC=/#CC=/' system.sh
verbose 5 add CC path to the kernel
LINE_NUM=$(grep -n "#CC=" system.sh | cut -f 1 -d : | tail -1)
sed -i ''$LINE_NUM's#$#\nCC=t '$CC'#' system.sh
verbose 5 Downloading rootfs
cd /$WDIR/$WORKSPACE/$ROOTFS
wget -c $ROOTFS_URL
verbose 5 extracting rootfs
tar xf $(echo $ROOTFS_URL | rev | cut -d / -f 1 | rev) 
