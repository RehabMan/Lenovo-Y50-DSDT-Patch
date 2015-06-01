#!/bin/bash

#set -x

unpatched=/System/Library/Extensions

# AppleHDA patching function
function createAppleHDAInjector()
{
# create AppleHDA injector for Clover setup...
    echo -n "Creating AppleHDA injector for $1..."
    rm -Rf AppleHDA_$1.kext
    cp -R $unpatched/AppleHDA.kext/ AppleHDA_$1.kext
    rm -R AppleHDA_$1.kext/Contents/Resources/*
    rm -R AppleHDA_$1.kext/Contents/PlugIns
    rm -R AppleHDA_$1.kext/Contents/_CodeSignature
    rm -R AppleHDA_$1.kext/Contents/MacOS/AppleHDA
    rm AppleHDA_$1.kext/Contents/version.plist
    ln -s /System/Library/Extensions/AppleHDA.kext/Contents/MacOS/AppleHDA AppleHDA_$1.kext/Contents/MacOS/AppleHDA
    cp ./Resources_$1/layout/*.zlib AppleHDA_$1.kext/Contents/Resources/

    # fix versions (must be larger than native)
    plist=AppleHDA_$1.kext/Contents/Info.plist
    pattern='s/(\d*\.\d*(\.\d*)?)/9\1/'
    replace=`/usr/libexec/plistbuddy -c "Print :NSHumanReadableCopyright" $plist | perl -p -e $pattern`
    /usr/libexec/plistbuddy -c "Set :NSHumanReadableCopyright '$replace'" $plist
    replace=`/usr/libexec/plistbuddy -c "Print :CFBundleGetInfoString" $plist | perl -p -e $pattern`
    /usr/libexec/plistbuddy -c "Set :CFBundleGetInfoString '$replace'" $plist
    replace=`/usr/libexec/plistbuddy -c "Print :CFBundleVersion" $plist | perl -p -e $pattern`
    /usr/libexec/plistbuddy -c "Set :CFBundleVersion '$replace'" $plist
    replace=`/usr/libexec/plistbuddy -c "Print :CFBundleShortVersionString" $plist | perl -p -e $pattern`
    /usr/libexec/plistbuddy -c "Set :CFBundleShortVersionString '$replace'" $plist
if [ 0 -eq 0 ]; then
    # create AppleHDAHardwareConfigDriver overrides (injector personality)
    /usr/libexec/plistbuddy -c "Add ':HardwareConfigDriver_Temp' dict" $plist
    /usr/libexec/plistbuddy -c "Merge $unpatched/AppleHDA.kext/Contents/PlugIns/AppleHDAHardwareConfigDriver.kext/Contents/Info.plist ':HardwareConfigDriver_Temp'" $plist
    /usr/libexec/plistbuddy -c "Copy ':HardwareConfigDriver_Temp:IOKitPersonalities:HDA Hardware Config Resource' ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
    /usr/libexec/plistbuddy -c "Delete ':HardwareConfigDriver_Temp'" $plist
    /usr/libexec/plistbuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:HDAConfigDefault'" $plist
    #/usr/libexec/plistbuddy -c "Delete ':IOKitPersonalities:HDA Hardware Config Resource:PostConstructionInitialization'" $plist
    /usr/libexec/plistbuddy -c "Add ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' integer" $plist
    /usr/libexec/plistbuddy -c "Set ':IOKitPersonalities:HDA Hardware Config Resource:IOProbeScore' 2000" $plist
    /usr/libexec/plistbuddy -c "Merge ./Resources_$1/ahhcd.plist ':IOKitPersonalities:HDA Hardware Config Resource'" $plist
fi
    echo " Done."
}

createAppleHDAInjector "ALC283"

#createAppleHDAInjector "ALC283b"
