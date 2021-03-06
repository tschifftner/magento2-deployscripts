#!/usr/bin/env bash

VALID_ENVIRONMENTS=" live production staging devbox latest deploy integration "
PRODUCTION_ENVIRONMENTS=" live production staging "

MY_PATH=`dirname $(readlink -f "$0")`
RELEASEFOLDER=$(readlink -f "${MY_PATH}/../../..")

function usage {
    echo "Usage:"
    echo " $0 -e <environment> [-r <releaseFolder>] [-s]"
    echo " -e Environment (e.g. production, staging, devbox,...)"
    echo " -s If set the systemstorage will not be imported"
    echo ""
    exit $1
}

while getopts 'e:r:s' OPTION ; do
case "${OPTION}" in
        e) ENVIRONMENT="${OPTARG}";;
        r) RELEASEFOLDER=`echo "${OPTARG}" | sed -e "s/\/*$//" `;; # delete last slash
        s) SKIPIMPORTFROMSYSTEMSTORAGE=true;;
        \?) echo; usage 1;;
    esac
done

if [ ! -f "${RELEASEFOLDER}/pub/index.php" ] ; then echo "Invalid release folder" ; exit 1; fi
if [ ! -f "${RELEASEFOLDER}/bin/magento" ] ; then echo "Could not find bin/magento" ; exit 1; fi

# Checking environment
if [ -z "${ENVIRONMENT}" ]; then echo "ERROR: Please provide an environment code (e.g. -e staging)"; exit 1; fi
if [[ "${VALID_ENVIRONMENTS}" =~ " ${ENVIRONMENT} " ]] ; then
    echo "Environment: ${ENVIRONMENT}"
else
    echo "ERROR: Illegal environment code" ; exit 1;
fi


########################################################################################################################
# Link directories
########################################################################################################################

echo
echo "Linking to shared directories"
echo "-----------------------------"
SHAREDFOLDER="${RELEASEFOLDER}/../../shared"
if [ ! -d "${SHAREDFOLDER}" ] ; then
    echo "Could not find '../../shared'. Trying '../../../shared' now"
    SHAREDFOLDER="${RELEASEFOLDER}/../../../shared";
fi

if [ ! -d "${SHAREDFOLDER}" ] ; then echo "Shared directory ${SHAREDFOLDER} not found"; exit 1; fi
if [ ! -d "${SHAREDFOLDER}/media" ] ; then echo "Shared directory ${SHAREDFOLDER}/media not found"; exit 1; fi
if [ ! -d "${SHAREDFOLDER}/var/log" ] ; then echo "Shared directory ${SHAREDFOLDER}/var/log not found"; exit 1; fi

if [ -d "${RELEASEFOLDER}/pub/media" ]; then echo "Found existing pub/media folder that shouldn't be there"; exit 1; fi
if [ -d "${RELEASEFOLDER}/var/log" ]; then echo "Found existing var/log folder that shouldn't be there"; exit 1; fi

echo "Setting symlink (${RELEASEFOLDER}/pub/media) to shared media folder (${SHAREDFOLDER}/media)"
ln -s "${SHAREDFOLDER}/media" "${RELEASEFOLDER}/pub/media"  || { echo "Error while linking to shared media directory" ; exit 1; }

echo "Setting symlink (${RELEASEFOLDER}/var/log) to shared var/log folder (${SHAREDFOLDER}/var/log)"
mkdir -p "${RELEASEFOLDER}/var"
ln -s "${SHAREDFOLDER}/var/log" "${RELEASEFOLDER}/var/log"  || { echo "Error while linking to shared var/log directory" ; exit 1; }


########################################################################################################################
# Set permissions for directories
########################################################################################################################
echo
echo "Set permissions for directories"
echo "-----------------"
mkdir -p ${RELEASEFOLDER}/pub/static &&
chmod -R 774 ${RELEASEFOLDER}/pub/{media,static} &&
chmod -R 775 ${RELEASEFOLDER}/var || { echo "Cannot set permissions for directories" ; exit 1; }

########################################################################################################################
# Apply configuration settings
########################################################################################################################
echo
echo "Applying settings"
echo "-----------------"
cd "${RELEASEFOLDER}" || { echo "Error while switching to root directory" ; exit 1; }
if [ -f config/settings.csv ]; then
    vendor/bin/zettr.phar apply ${ENVIRONMENT} config/settings.csv --groups db || { echo "Error while applying settings" ; exit 1; }
    vendor/bin/zettr.phar apply ${ENVIRONMENT} config/settings.csv || { echo "Error while applying settings" ; exit 1; }
else
    echo "No config/settings.csv found!"
fi
echo

########################################################################################################################
# Run upgrade scripts
########################################################################################################################

echo
echo "Triggering Magento setup scripts via magento-cli"
echo "------------------------------------------------"
cd -P "${RELEASEFOLDER}/" || { echo "Error while switching to htdocs directory" ; exit 1; }
php bin/magento setup:upgrade --keep-generated || { echo "Error while triggering the update scripts using magento-cli" ; exit 1; }


########################################################################################################################
# Set production mode
########################################################################################################################
echo
echo "Set deploy mode"
echo "-----------------"
if [[ "${PRODUCTION_ENVIRONMENTS}" =~ " ${ENVIRONMENT} " ]] ; then
    php bin/magento deploy:mode:set production || { echo "Error while settings deploy mode" ; exit 1; }
else
    php bin/magento deploy:mode:set developer || { echo "Error while settings deploy mode" ; exit 1; }
fi

echo
echo "Successfully completed installation."
echo