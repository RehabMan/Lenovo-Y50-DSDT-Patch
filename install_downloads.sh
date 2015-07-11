#set -x

SUDO=sudo
#SUDO='echo #'
#SUDO=nothing
TAG=`pwd`/tools/tag

function check_directory
{
    for x in $1; do
        if [ -e "$x" ]; then
            return 1
        else
            return 0
        fi
    done
}

function nothing
{
    :
}

function install_kext
{
    if [ "$1" != "" ]; then
        echo installing $1 to /System/Library/Extensions
        $SUDO rm -Rf /System/Library/Extensions/`basename $1`
        $SUDO cp -Rf $1 /System/Library/Extensions
        $SUDO $TAG -a Gray /System/Library/Extensions/`basename $1`
    fi
}

function install_app
{
    if [ "$1" != "" ]; then
        echo installing $1 to /Applications
        $SUDO rm -Rf /Applications/`basename $1`
        $SUDO cp -Rf $1 /Applications
        $SUDO $TAG -a Gray /Applications/`basename $1`
    fi
}

function install_binary
{
    if [ "$1" != "" ]; then
        echo installing $1 to /usr/bin
        $SUDO rm -f /usr/bin/`basename $1`
        $SUDO cp -f $1 /usr/bin
        $SUDO $TAG -a Gray /usr/bin/`basename $1`
    fi
}

function install
{
    installed=0
    out=${1/.zip/}
    rm -Rf $out/* && unzip -q -d $out $1
    check_directory $out/Release/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/Release/*.kext; do
            if [[ "$2" == "" || "`echo $kext | grep -vE "$2"`" != "" ]]; then
                install_kext $kext
            fi
        done
        installed=1
    fi
    check_directory $out/*.kext
    if [ $? -ne 0 ]; then
        for kext in $out/*.kext; do
            install_kext $kext
        done
        installed=1
    fi
    check_directory $out/Release/*.app
    if [ $? -ne 0 ]; then
        for app in $out/Release/*.app; do
            install_app $app
        done
        installed=1
    fi
    check_directory $out/*.app
    if [ $? -ne 0 ]; then
        for app in $out/*.app; do
            install_app $app
        done
        installed=1
    fi
    if [ $installed -eq 0 ]; then
        check_directory $out/*
        if [ $? -ne 0 ]; then
            for tool in $out/*; do
                install_binary $tool
            done
        fi
    fi
}

if [ "$(id -u)" != "0" ]; then
    echo "This script requires superuser access..."
fi

# unzip/install kexts
check_directory ./downloads/kexts/*.zip
if [ $? -ne 0 ]; then
    echo Installing kexts...
    cd ./downloads/kexts
    for kext in *.zip; do
        install $kext "FakePCIID_BCM57XX|FakePCIID_AR9280|BrcmPatchRAM|BrcmBluetoothInjector"
    done
    if [[ "`sw_vers -productVersion`" == 10.11* ]]; then
        # 10.11 needs only bluetooth injector
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmBluetoothInjector.kext && cd ../..
        # remove uploader just in case
        $SUDO rm -Rf /System/Library/Extensions/BrcmPatchRAM.kext
    else
        # prior to 10.11, need uploader and ACPIBacklight.kext
        cd RehabMan-BrcmPatchRAM*/Release && install_kext BrcmPatchRAM.kext && cd ../..
        cd RehabMan-Backlight*/Release && install_kext ACPIBacklight.kext && cd ../..
        # remove injector just in case
        $SUDO rm -Rf /System/Library/Extensions/BrcmBluetoothInjector.kext
    fi
    cd ../..
fi

# install (injector) kexts in the repo itself
install_kext AppleHDA_ALC283.kext

if [[ "`sw_vers -productVersion`" == 10.11* ]]; then
    #install_kext USBXHC_y50.kext
    # create custom AppleBacklightInjector.kext and install
    ./patch_backlight.sh
    install_kext AppleBacklightInjector.kext
    # remove ACPIBacklight.kext if it is installed (doesn't work with 10.11)
    if [ -d /System/Library/Extensions/ACPIBacklight.kext ]; then
        $SUDO rm -Rf /System/Library/Extensions/ACPIBacklight.kext
    fi
fi

#check_directory *.kext
#if [ $? -ne 0 ]; then
#    for kext in *.kext; do
#        install_kext $kext
#    done
#fi

# force cache rebuild with output
$SUDO touch /System/Library/Extensions && $SUDO kextcache -u /

# unzip/install tools
check_directory ./downloads/tools/*.zip
if [ $? -ne 0 ]; then
    echo Installing tools...
    cd ./downloads/tools
    for tool in *.zip; do
        install $tool
    done
    cd ../..
fi

# install VoodooPS2Daemon
echo Installing VoodooPS2Daemon to /usr/bin and /Library/LaunchDaemons...
cd ./downloads/kexts/RehabMan-Voodoo-*
$SUDO cp ./Release/VoodooPS2Daemon /usr/bin
$SUDO $TAG -a Gray /usr/bin/VoodooPS2Daemon
$SUDO cp ./org.rehabman.voodoo.driver.Daemon.plist /Library/LaunchDaemons
$SUDO $TAG -a Gray /Library/LaunchDaemons/org.rehabman.voodoo.driver.Daemon.plist
cd ../..
