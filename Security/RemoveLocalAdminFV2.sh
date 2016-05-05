#!/bin/bash

#####################################################################################################
#
# ABOUT THIS PROGRAM
#
# NAME
#   RemoveLocalAdminFV2.sh -- Removes the local admin account from FileVault if the logged in user is enabled
#
# SYNOPSIS
#   sudo RemoveLocalAdminFV2.sh
#
# LICENSE
#   Distributed under the MIT License
#
####################################################################################################
#
# HISTORY
#
#   Version: 1.0
#
#   - v.1.0 Luis Lugo, 03.05.2016 :
#
####################################################################################################

# Set the variables
userEnabled=0
locAdminEnabled=0
if [[ $4 != "" ]]
then
    localAdmin=$4
else
    localAdmin="localadmin"
fi

# Create the FileVault user array
fdeUsers=( `fdesetup list | cut -d "," -f 1` )

# Get the currently logged-in user
loggedInUser=`ls -l /dev/console | cut -d " " -f 4`

# Check if the current user is part of the FileVault users
for (( i = 0 ; i<"${#fdeUsers[@]}" ; i++ ))
do
    if [[ $userEnabled -eq 0 && "${fdeUsers[i]}" == "$loggedInUser" ]]
    then
        userEnabled=1
        for (( i = 0 ; i<"${#fdeUsers[@]}" ; i++ ))
        do
            # If the local admin account is enabled, remove the local admin account
            if [[ "${fdeUsers[i]}" == "$localAdmin" ]]
            then
                locAdminEnabled=1
                fdesetup remove -user $localAdmin
            fi
        done
    fi
done

# Report back what was found
if [[ $userEnabled -eq 1 ]]
then
    echo "$loggedInUser is FileVault enabled!"
    if [[ $locAdminEnabled -eq 1 ]]
    then
        echo "$localAdmin was FileVault enabled!"
    else
        echo "$localAdmin was NOT FileVault enabled!"
    fi
else
    echo "$loggedInUser is NOT FileVault enabled!"
fi
