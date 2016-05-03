#!/bin/bash

################################################################################################
# ABOUT THIS PROGRAM
#
# NAME
#   RemoveCertSHA1.sh -- Removes a certificate in the system keychain based on it's SHA-1 hash
#
# SYNOPSIS
#   Add RemoveCertSHA1.sh to the scripts in a policy
#   Pass the SHA-1 hash to the script as $4
#
# LICENSE
#   Distributed under the MIT license
#
################################################################################################
#
# HISTORY
#   Version: 1.0
#
#   - v.1.0 Luis Lugo, 2.5.2016
#
################################################################################################

echo "Using $4 as the SHA-1 hash"

# Find all certificates in the System keychain and put them in an array by their SHA-1 hash
IFS=$'\n'
sha1Array=( $(security find-certificate -a -Z '/Library/Keychains/System.keychain' | grep -e 'SHA-1 hash:' | cut -c 13-54) )

echo "Number of certificates found: ${#sha1Array[@]}"

# Loop through the array of certificate hashes and look for the one passed to the script
for (( i = 0 ; i<"${#sha1Array[@]}" ; i++ ))
do
    # Is the current array member the one we're looking for?
    if [[ "${sha1Array[i]}" == "$4" ]]
    then
        # This is the certificate we're looking for
        echo "Certificate found!"
        security delete-certificate -Z $4
        # Did it delete successfully?
        if [[ $? == 0 ]]
        then
            echo "SUCCESS: Certificate removed!"
            jamf recon
            exit 0
        else
            echo "ERROR: Failed to remove certificate!"
            exit $?
        fi
    fi
done

# The certificate was not found in the array
echo "INFO: Certificate NOT found!"
exit 0
