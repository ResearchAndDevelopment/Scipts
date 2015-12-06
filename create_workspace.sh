#!/bin/bash
#============================
#Reference https://eewiki.net/display/linuxonarm/BeagleBone+Black
#Author: Alex Jafari
#Email:alexjafari2005@gmail.com
#You must be root to run this script
if [[ $EUID -ne 0 ]];then 
	echo "This script must be run as root" 
	exit 0
fi
#Variables
#DEBUG_LEVEL does what it sounds like. 0 is disabled and 5 most verbose
init_variables()
{
	VERBOSE_VAL=5
	WORKSPACE=workspace
	BOOTLDR=bootldr
	BOOTLDR_VER=v2015.10
	BOOTLDR_URL=git://git.denx.de/u-boot
	DEBUG=debug
	IMAGES=images
	PROJECT=project
	ROOTFS=rootfs
#	ROOTFS_URL=https://rcn-ee.com/rootfs/eewiki/minfs/debian-8.1-minimal-armhf-2015-06-09.tar.xz
#	ROOTFS_URL=http://ynezz.ibawizard.net/beagleboard/trusty/ubuntu-14.04-console-armhf-2014-07-06.tar.xz
	ROOTFS_URL=https://rcn-ee.com/rootfs/eewiki/minfs/ubuntu-14.04.3-minimal-armhf-2015-09-07.tar.xz
	UBOOT_PATCH_URL=https://rcn-ee.com/repos/git/u-boot-patches/v2015.10/0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
	TMP=tmp
	BUILDTOOLS=build-tools
	DOC=doc
	KERNEL=kernel
	SYSAPPS=sysapps
	TOOLS=tools
	KERNEL_URL=https://github.com/RobertCNelson/bb-kernel
	KERNEL_VER=origin/am33x-v3.8
	CC=gcc-linaro-arm-linux-
	CC_URL=https://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.xz
	#CC_URL=PUT ADDRESS FOR ARAGO
	WDIR=`pwd`
}
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
	read -t 20 -p "Enter $@:1 value or press enter for default \"$1\": " tmp
	if [ "x$tmp" = "x" ];then
		echo $1 
	else	
		echo $tmp
	fi	
}
#creatting workspace with the directory structore
create_workspace()
{
	WORKSPACE=$(prompt $WORKSPACE)
	verbose 5 workspace is $WORKSPACE
	mkdir -p $WORKSPACE
	cd $WORKSPACE
	mkdir -p $BOOTLDR $DEBUG $IMAGES $PROJECT $ROOTFS $TMP \
		$BUILDTOOLS $DOC $KERNEL $SYSAPPS $TOOLS
}
#Prepare for downloading cross compiler
#for linaro you need 32 bit libraries
Install_cc()
{
#	verbose 5 Install 32 bit libraries for $CC
#	dpkg --add-architecture i386
#	apt-get install libc6:i386 libstdc++6:i386 libncurses5:i386 zlib1g:i386
	#Download cross compiler tool
	verbose 5 downloading cross compiler tools 
	cd $WDIR/$WORKSPACE/$TOOLS
        if [ -e `echo $CC_URL |rev | cut -d / -f 1| rev` ]; then
                verbose 5 $CC is already downloaded
        else
                wget -c $CC_URL
		verbose 5 extracting $CC tools
		tar xf $(echo $CC_URL | rev | cut -d / -f 1 | rev) 
	fi
	verbose 5 Verifying $CC installation
	CC_FULL_NAME=$WDIR/$WORKSPACE/$TOOLS/`ls -l| grep ^d | awk '{print $9}'`/bin/arm-linux-gnueabihf-
	if [[ $(${CC_FULL_NAME}gcc --version| grep -w  ^arm-linux-gnueabihf-gcc) ]];then
		verbose 5 CC installation succeeded 
	else 
		verbose 0 CC installation failed
		verbose 0 "Try installing 32 bit libraties for ubuntu by uncommenting first 3 lines of Install_cc() or extract CC again."
		exit 1
	fi
}
git_download()
{
        local BRANCH=tmp
	local VER=${1}_VER
	local URL=${1}_URL
        cd $WDIR/$WORKSPACE/${!1}
	verbose 3 Directory ${!1} : $WDIR/$WORKSPACE/${!1}
	local DIRECTORY=$(echo ${!URL} |rev | cut -d / -f 1| rev)
        if [ ! -e $DIRECTORY ];then 
                verbose 5 cloning $1 from "${!URL}"
                git clone --recursive ${!URL}
        fi
        cd $DIRECTORY
        verbose 5 checking out ${!VER} to branch $BRANCH
        git rev-parse --verify $BRANCH &>/dev/null|| git checkout ${!VER} -b $BRANCH
}
download_u-boot()
{
	git_download BOOTLDR
	if [ ! -e `echo $UBOOT_PATCH_URL |rev | cut -d / -f 1| rev` ];then
		verbose 5 Downloading patches from $UBOOT_PATCH_URL
		wget -c $UBOOT_PATCH_URL 
	        verbose 5 applying patches to u-boot
	        patch -p1 < 0001-am335x_evm-uEnv.txt-bootz-n-fixes.patch
	fi
}
build_u-boot()
{
        verbose 5 configuring and building u-boot
#        make ARCH=arm CROSS_COMPILE=${CC_FULL_NAME} distclean
        make ARCH=arm CROSS_COMPILE=${CC_FULL_NAME} am335x_evm_defconfig
        make ARCH=arm CROSS_COMPILE=${CC_FULL_NAME}
}
download_kernel()
{
	git_download KERNEL
	verbose 5 configuring system variables
	cp system.sh.sample system.sh
	verbose 5 setting up $CC_FULL_NAME path
	verbose 5 comment out all the CCs
	sed -i 's/^CC=/#CC=/' system.sh
	verbose 5 add CC path to the kernel
	LINE_NUM=$(grep -n "#CC=" system.sh | cut -f 1 -d : | tail -1)
	if [ "x$LINE_NUM" != "x" ]; then 
		sed -i ''$LINE_NUM's#$#\nCC='$CC_FULL_NAME'#' system.sh
	else
		sed -i '1a CC='$CC_FULL_NAME'' system.sh
	fi
}
download_rootfs()
{
	cd /$WDIR/$WORKSPACE/$ROOTFS
	if [ ! -e `echo $ROOTFS_URL |rev | cut -d / -f 1| rev` ]; then
		verbose 5 Downloading rootfs
		wget -c $ROOTFS_URL
		verbose 5 extracting rootfs
		tar xf $(echo $ROOTFS_URL | rev | cut -d / -f 1 | rev) 
	fi
}
init_variables
create_workspace
Install_cc
download_u-boot
build_u-boot
download_kernel
download_rootfs
