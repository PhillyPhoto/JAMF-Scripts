#!/bin/bash

#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#	CitrixReceiverUpdate.sh -- Installs or updates Citrix Receiver
#
# SYNOPSIS
#	sudo CitrixReceiverUpdate.sh
#
# EXIT CODES
#   0 - Citrix Receiver is current
#   1 - Citrix Receiver installed successfully
#   2 - Citrix Receiver NOT installed
#   3 - Citrix Receiver update unsuccessful
#   4 - Citrix Receiver is running or was attempted to be installed manually and user deferred install
#   5 - Not an Intel-based Mac
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.0
#
#   - v.1.0 Luie Lugo, 09.05.2016 : Updates Citrix Receiver
#
####################################################################################################
# Script to download and install Citrix Receiver.

# Setting variables
receiverProcRunning=0

# Echo function
echoFunc () {
    # Date and Time function for the log file
    fDateTime () { echo $(date +"%a %b %d %T"); }

    # Title for beginning of line in log file
    Title="InstallLatestCitrixReceiver:"

    # Header string function
    fHeader () { echo $(fDateTime) $(hostname) $Title; }
    
    # Check for the log file
    if [ -e "/Library/Logs/CitrixReceiverUpdateScript.log" ]; then
        echo $(fHeader) "$1" >> "/Library/Logs/CitrixReceiverUpdateScript.log"
    else
        cat > "/Library/Logs/CitrixReceiverUpdateScript.log"
        if [ -e "/Library/Logs/CitrixReceiverUpdateScript.log" ]; then
            echo $(fHeader) "$1" >> "/Library/Logs/CitrixReceiverUpdateScript.log"
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
        0) exitCode="0 - Citrix Receiver is current! Version: $2";;
        1) exitCode="1 - SUCCESS: Citrix Receiver has been updated to version $2";;
        2) exitCode="2 - ERROR: Citrix Receiver NOT installed!";;
        3) exitCode="3 - ERROR: Citrix Receiver update unsuccessful, version remains at  $2!";;
        4) exitCode="4 - ERROR: Citrix Receiver is running or was attempted to be installed manually and user deferred install.";;
        5) exitCode="5 - ERROR: Not an Intel-based Mac.";;
        *) exitCode="$1";;
    esac
    echoFunc "Exit code: $exitCode"
    echoFunc "======================== Script Complete ========================"
    exit $1
}

# Check to see if Citrix Receiver is running
receiverRunningCheck () {
    processNum=$(ps aux | grep "Citrix Receiver" | wc -l)
    if [ $processNum -gt 1 ]
    then
        # Receiver is running, prompt the user to close it or defer the upgrade
        receiverRunning
    fi
}

# If Citrix Receiver is running, prompt the user to close it
receiverRunning () {
    echoFunc "Citrix Receiver appears to be running!"
    hudTitle="Citrix Receiver Update"
    hudDescription="Citrix Receiver needs to be updated. Please save your work and close the application to proceed. You can defer if needed.

If you have any questions, please call the help desk."
    
    #sudo -u $(ls -l /dev/console | awk '{print $3}')    utility
    jamfHelperPrompt=`/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -title "$hudTitle" -description "$hudDescription" -button1 "Proceed" -button2 "Defer" -defaultButton 1`

    case $jamfHelperPrompt in
        0)
            echoFunc "Proceed selected"
            receiverProcRunning=1
            receiverRunningCheck
        ;;
        2)
            echoFunc "Deferment Selected"
            exitFunc 4
        ;;
        *)
            echoFunc "Selection: $?"
            #receiverProcRunning=1
            #receiverRunningCheck
            exitFunc 3 "Unknown"
        ;;
    esac
}

# If Citrix Receiver is running, prompt the user to close it
receiverUpdateMan () {
    echoFunc "Citrix Receiver appears to be running!"
    hudTitle="Citrix Receiver Update"
    hudDescription="Citrix Receiver needs to be updated. You will see a program downloading the installer. You can defer if needed.

If you have any questions, please call the help desk."

    jamfHelperPrompt=`/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -title "$hudTitle" -description "$hudDescription" -button1 "Defer" -button2 "Proceed" -defaultButton 1 -timeout 60 -countdown`

    case $jamfHelperPrompt in
        0)
            echoFunc "Deferment Selected"
            exitFunc 4
        ;;
        2)
            echoFunc "Proceed selected"
            receiverRunningCheck
        ;;
        *)
            echoFunc "Selection: $?"
            exitFunc 3 "Unknown"
        ;;
    esac
}

echoFunc ""
echoFunc "======================== Starting Script ========================"

# Are we running on Intel?
if [ '`/usr/bin/uname -p`'="i386" -o '`/usr/bin/uname -p`'="x86_64" ]; then
    ## Get OS version and adjust for use with the URL string
    OSvers_URL=$( sw_vers -productVersion | sed 's/[.]/_/g' )

    ## Set the User Agent string for use with curl
    userAgent="Mozilla/5.0 (Macintosh; Intel Mac OS X ${OSvers_URL}) AppleWebKit/535.6.2 (KHTML, like Gecko) Version/5.2 Safari/535.6.2"

    # Get the latest version of Receiver available from Citrix's Receiver page.
    latestver=``
    while [ -z "$latestver" ]
    do
        latestver=`curl -s -L https://www.citrix.com/downloads/citrix-receiver/mac/receiver-for-mac-latest.html | grep "<h1>Receiver " | awk '{print $2}'`
    done

    echoFunc "Latest Citrix Receiver Version is: $latestver"
    latestvernorm=`echo ${latestver}`
    # Get the version number of the currently-installed Citrix Receiver, if any.
    if [ -e "/Applications/Citrix Receiver.app" ]; then
        currentinstalledapp="Citrix Receiver"
        currentinstalledver=`/usr/bin/defaults read /Applications/Citrix\ Receiver.app/Contents/Info CFBundleShortVersionString`
        echoFunc "Current Receiver installed version is: $currentinstalledver"
        if [ ${latestvernorm} = ${currentinstalledver} ]; then
            exitFunc 0 "${currentinstalledapp} ${currentinstalledver}"
        else
            # Not running the latest version, check if Receiver is running
            receiverRunningCheck
        fi
    else
        currentinstalledapp="None"
        currentinstalledver="N/A"
        exitFunc 2
    fi

    # Build URL and dmg file name
    CRCurrVersNormalized=$( echo $latestver | sed -e 's/[.]//g' )
    echoFunc "CRCurrVersNormalized: $CRCurrVersNormalized"
    url1="https:"
    url2=`curl -s -L https://www.citrix.com/downloads/citrix-receiver/mac/receiver-for-mac-latest.html | grep "ctx-dl-link ie10-download-hide promptDw\"" | awk '{print $8}' | cut -c 6-112`
    url=`echo "${url1}${url2}"`
    echoFunc "Latest version of the URL is: $url"
    dmgfile="Citrix_Rec_${CRCurrVersNormalized}.dmg"

    # Compare the two versions, if they are different or Citrix Receiver is not present then download and install the new version.
    if [ "${currentinstalledver}" != "${latestvernorm}" ]; then
        echoFunc "Current Receiver version: ${currentinstalledapp} ${currentinstalledver}"
        echoFunc "Available Receiver version: ${latestver} => ${CRCurrVersNormalized}"
        echoFunc "Downloading newer version."
        curl -s -o /tmp/${dmgfile} ${url}
        case $? in
            0)
                echoFunc "Checking if the file exists after downloading."
                if [ -e "/tmp/${dmgfile}" ]; then
                    receiverFileSize=$(du -k "/tmp/${dmgfile}" | cut -f 1)
                    echoFunc "Downloaded File Size: $receiverFileSize kb"
                else
                    echoFunc "File NOT downloaded!"
                    exitFunc 3 "${currentinstalledapp} ${currentinstalledver}"
                fi
                echoFunc "Checking if Receiver is running one last time before we install"
                receiverRunningCheck
                echoFunc "Mounting installer disk image."
                hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
                echoFunc "Installing..."
                installer -pkg /Volumes/Citrix\ Receiver/Install\ Citrix\ Receiver.pkg -target / > /dev/null

                sleep 10
                echoFunc "Unmounting installer disk image."
                umount "/Volumes/Citrix Receiver"
                sleep 10
                echoFunc "Deleting disk image."
                rm /tmp/${dmgfile}

                #double check to see if the new version got update
                if [ -e "/Applications/Citrix Receiver.app" ]; then
                    newlyinstalledver=`/usr/bin/defaults read /Applications/Citrix\ Receiver.app/Contents/Info CFBundleShortVersionString`
                    if [ "${latestvernorm}" = "${newlyinstalledver}" ]; then
                        echoFunc "SUCCESS: Citrix Receiver has been updated to version ${newlyinstalledver}, issuing JAMF recon command"
                        jamf recon
                        if [ $receiverProcRunning -eq 1 ];
                        then
                            /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -title "Citrix Receiver Updated" -description "Citrix Receiver has been updated to version ${newlyinstalledver}." -button1 "OK" -defaultButton 1
                        fi
                        exitFunc 1 "${newlyinstalledver}"
                    else
                        exitFunc 3 "${currentinstalledapp} ${currentinstalledver}"
                    fi
                else
                    exitFunc 3 "${currentinstalledapp} ${currentinstalledver}"
                fi
            ;;
            *)
                echoFunc "Curl function failed on download! Error: $?. Review error codes here: https://curl.haxx.se/libcurl/c/libcurl-errors.html"
            ;;
        esac
    else
        # If Citrix Receiver is up to date already, just log it and exit.
        exitFunc 0 "${currentinstalledapp} ${currentinstalledver}"
    fi
else
    # This script is for Intel Macs only.
    exitFunc 5
fi
