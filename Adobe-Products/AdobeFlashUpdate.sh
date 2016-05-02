#!/bin/sh

#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	AdobeFlashUpdate.sh -- Installs or updates Adobe Flash Player
#
# SYNOPSIS
#	sudo AdobeFlashPlayerUpdate.sh
#
# LICENSE
#   Distributed under the MIT License
#
# EXIT CODES
#   0 - Adobe Flash Player installed successfully
#   1 - Adobe Flash Player is current
#   2 - Adobe Flash Player NOT installed
#   3 - Adobe Flash Player update unsuccessful
#   4 - Adobe Flash Player is not available for Mac OS X 10.5.8 or below.
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.0
#
#   - v.1.0 Luie Lugo, 26.04.2016 : updates Flash Player to the latest version
#
####################################################################################################
# This script downloads and installs the latest Flash player for compatible Macs

# Echo function
echoFunc () {
    # Date and Time function for the log file
    fDateTime () { echo $(date +"%a %b %d %T"); }

    # Title for beginning of line in log file
    Title="InstallLatestFlashPlayer:"

    # Header string function
    fHeader () { echo $(fDateTime) $(hostname) $Title; }

    # Check for the log file, if not found, create it, then write to it
    if [ -e "/Library/Logs/AdobeFlashPlayerUpdateScript.log" ]; then
        echo $(fHeader) "$1" >> "/Library/Logs/AdobeFlashPlayerUpdateScript.log"
    else
        cat > "/Library/Logs/AdobeFlashPlayerUpdateScript.log"
        if [ -e "/Library/Logs/AdobeFlashPlayerUpdateScript.log" ]; then
            echo $(fHeader) "$1" >> "/Library/Logs/AdobeFlashPlayerUpdateScript.log"
        else
            echo "Failed to create log file, writing to JAMF log"
            echo $(fHeader) "$1" >> "/var/log/jamf.log"
        fi
    fi

    # Echo out
    echo $(fDateTime) ": $1"
}

# Exit function
exitFunc () {
    case $1 in
        0) exitCode="1 - SUCCESS: Flash Player has been updated to version $2";;
        1) exitCode="0 - INFO: Flash Player is current! Version: $2";;
        2) exitCode="2 - INFO: Adobe Flash Player NOT installed!";;
        3) exitCode="3 - ERROR: Adobe Flash Player update unsuccessful, version remains at $2!";;
        4) exitCode="4 - ERROR: Adobe Flash Player is not available for Mac OS X 10.5.8 or below.";;
        *) exitCode="$1";;
    esac
    echoFunc "Exit code: $exitCode"
    echoFunc "======================== Script Complete ========================"
    exit $1
}

echoFunc ""
echoFunc "======================== Starting Script ========================"

## Get OS version and adjust for use with the URL string
OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )

## Set the User Agent string for use with curl
userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

# Get the latest version of Flash Player available from Adobe's About Flash Player page.
latestver=``
while [ -z "$latestver" ]
    do
    latestver=`curl -s -L -A "$userAgent" https://get.adobe.com/flashplayer/ | grep "<strong>Version" | /usr/bin/sed -e 's/<[^>][^>]*>//g' | /usr/bin/awk '{print $2}'`
done

if [ -e "/Library/Internet Plug-Ins/Flash Player.plugin" ]; then
    currentver=`/usr/libexec/Plistbuddy -c "Print :CFBundleVersion" /Library/Internet\ Plug-Ins/Flash\ Player.plugin/Contents/Info.plist CFBundleVersion`
    if [ "$latestver" -eq "$currentver" ]; then
        exitFunc 1 "$currentver"
    else
        echoFunc "Current version: $currentver, Latest version: $latestver"
        echoFunc "Determining OS version"
        osvers=$(sw_vers -productVersion | awk -F. '{print $2}')

        echoFunc "Determining current major version of Adobe Flash for use with the fileURL variable"
        flash_major_version=`/usr/bin/curl --silent http://fpdownload2.macromedia.com/get/flashplayer/update/current/xml/version_en_mac_pl.xml | cut -d , -f 1 | awk -F\" '/update version/{print $NF}'`

        echoFunc "Specify the complete address of the Adobe Flash Player disk image"
        fileURL="http://fpdownload.macromedia.com/get/flashplayer/current/licensing/mac/install_flash_player_"$flash_major_version"_osx_pkg.dmg"

        echoFunc "Specify name of downloaded disk image"
        flash_dmg="/tmp/flash.dmg"

        if [[ ${osvers} -lt 6 ]]; then
            exitFunc 4
        elif [[ ${osvers} -ge 6 ]]; then
            echoFunc "Downloading the latest Adobe Flash Player software disk image"
            /usr/bin/curl --output "$flash_dmg" "$fileURL"
            case $? in
                0)
                    echoFunc "Specifying a /tmp/flashplayer.XXXX mountpoint for the disk image"
                    TMPMOUNT=`/usr/bin/mktemp -d /tmp/flashplayer.XXXX`

                    echoFunc "Mounting the latest Flash Player disk image to /tmp/flashplayer.XXXX mountpoint"
                    hdiutil attach "$flash_dmg" -mountpoint "$TMPMOUNT" -nobrowse -noverify -noautoopen

                    pkg_path="$(/usr/bin/find $TMPMOUNT -maxdepth 1 \( -iname \*Flash*\.pkg -o -iname \*Flash*\.mpkg \))"

                    if [[ ${pkg_path} != "" ]]; then
                        if [[ ${osvers} -eq 6 ]]; then
                            echoFunc "OS X 10.6.*, installing Adobe Flash Player from the installer package stored inside the disk image"
                            /usr/sbin/installer -dumplog -verbose -pkg "${pkg_path}" -target "/"
                        elif [[ ${osvers} -ge 7 ]]; then
                            echoFunc "OS X 10.7.* or greater, checking for certificate"
                            signature_check=`/usr/sbin/pkgutil --check-signature "$pkg_path" | awk /'Developer ID Installer/{ print $5 }'`
                            if [[ ${signature_check} = "Adobe" ]]; then
                                echoFunc "Signature check passed, installing Adobe Flash Player from the installer package stored inside the disk image"
                                /usr/sbin/installer -dumplog -verbose -pkg "${pkg_path}" -target "/"
                            fi
                        fi
                    fi

                    echoFunc "Unmounting the Flash Player disk image from /tmp/flashplayer.XXXX"
                    /usr/bin/hdiutil detach "$TMPMOUNT"

                    echoFunc "Removing the /tmp/flashplayer.XXXX mountpoint"
                    /bin/rm -rf "$TMPMOUNT"

                    echoFunc "Removing the downloaded disk image"
                    /bin/rm -rf "$flash_dmg"
                ;;
                *)
                    echoFunc "Curl function failed! Error: $?."
                    exitFunc 3 "$currentver"
                ;;
            esac
        fi

        if [ -e "/Library/Internet Plug-Ins/Flash Player.plugin" ]; then
            newver=`/usr/libexec/Plistbuddy -c "Print :CFBundleVersion" /Library/Internet\ Plug-Ins/Flash\ Player.plugin/Contents/Info.plist CFBundleVersion`
            if [ "$latestver" -eq "$newver" ]; then
                exitFunc 0 "$newver"
            else
                exitFunc 3 "$currentver"
            fi
        else
            exitFunc 3 "$currentver"
        fi
    fi
else
    exitFunc 2
fi

exitFunc $?
