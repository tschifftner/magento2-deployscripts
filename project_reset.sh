#!/bin/bash -e

# Get absolute path to main directory
ABSPATH=$(cd "${0%/*}" 2>/dev/null; echo "${PWD}/${0##*/}")
SOURCE_DIR=`dirname "${ABSPATH}"`

if [ -a "${SOURCE_DIR}/../../.htaccess" ]; then
    PROJECT_WEBROOT="${SOURCE_DIR}/../.."
fi

function usage {
    echo "Usage:"
    echo "$0 -e <environment> -p <projectWebRootPath> -s <systemStorageRootPath> [-a <awsCliProfile>] [-f]"
    echo "    -p <projectWebRootPath>       Project web root path (htdocs)"
    echo "    -s <systemStorageRootPath>    Systemstorage project root path"
    echo "    -f                            If set file will be skipped (database only)"
    echo ""
    echo "Example:"
    echo "    -p /var/www/projectname/deploy/htdocs -s /home/projectstorage/projectname/backup/deploy"
    exit $1
}

function error_exit {
	echo "$1" 1>&2
	exit 1
}

function usage_exit {
    echo "$1" 1>&2
    usage 1
}


# Process options
while getopts 'e:p:s:a:f' OPTION ; do
    case "${OPTION}" in
        e) ENVIRONMENT="${OPTARG}";;
        p) PROJECT_WEBROOT=`echo "${OPTARG}" | sed -e "s/\/*$//" `;; # delete last slash
        s) SYSTEMSTORAGEPATH=`echo "${OPTARG}" | sed -e "s/\/*$//" `;; # delete last slash
        a) AWSCLIPROFILE=${OPTARG};;
        f) SKIPFILES=1;;
        \?) echo; usage 1;;
    esac
done

if [ ! -d "${PROJECT_WEBROOT}" ] ; then usage_exit "Could not find project root ${PROJECT_WEBROOT}"; fi
if [ ! -f "${PROJECT_WEBROOT}/index.php" ] ; then usage_exit "Invalid ${PROJECT_WEBROOT} (could not find index.php)"; fi

# Checking environment
VALID_ENVIRONMENTS=`head -n 1 "${PROJECT_WEBROOT}/config/settings.csv" | sed "s/^.*DEFAULT,//" | sed "s/,/ /g" | sed "s/\r//"`

if [ -z "${ENVIRONMENT}" ]; then error_exit "ERROR: Please provide an environment code (e.g. -e staging)"; fi
if [[ " ${VALID_ENVIRONMENTS} " =~ " ${ENVIRONMENT} " ]] ; then
    echo "Environment: ${ENVIRONMENT}"
else
    error_exit "ERROR: Illegal environment code ${ENVIRONMENT}"
fi


function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    rm -rf "${SYSTEMSTORAGE_LOCAL}"
}

if [[ "${SYSTEMSTORAGEPATH}" =~ ^s3:// ]] ; then

    SYSTEMSTORAGE_LOCAL=`mktemp -d`
    trap cleanup EXIT

    if [ -z "${AWSCLIPROFILE}" ] ; then usage_exit "No awsCliProfile given"; fi
    echo "Downloading project storage from S3"
    aws --profile ${AWSCLIPROFILE} s3 cp --recursive "${SYSTEMSTORAGEPATH}" "${SYSTEMSTORAGE_LOCAL}" || error_exit "Error while downloading package from S3"
else
    SYSTEMSTORAGE_LOCAL=${SYSTEMSTORAGEPATH}
fi

if [ ! -d "${SYSTEMSTORAGE_LOCAL}" ] ; then usage_exit "Could not find project storage root $SYSTEMSTORAGE_LOCAL"; fi
if [ ! -d "${SYSTEMSTORAGE_LOCAL}/database" ] ; then error_exit "Invalid $SYSTEMSTORAGE_LOCAL (could not find database folder)"; fi
if [ ! -f "${SYSTEMSTORAGE_LOCAL}/database/combined_dump.sql.gz" ] ; then error_exit "Invalid $SYSTEMSTORAGE_LOCAL (could not find combined_dump.sql.gz)"; fi
if [ ! -f "${SYSTEMSTORAGE_LOCAL}/database/created.txt" ] ; then error_exit "Invalid $SYSTEMSTORAGE_LOCAL (created.txt)"; fi

if [ -z "${SKIPFILES}" ] ; then
    if [ ! -d "${SYSTEMSTORAGE_LOCAL}/files" ] ; then usage_exit "Invalid $SYSTEMSTORAGE_LOCAL (could not find files folder)"; fi
fi


n98="/usr/bin/php -d apc.enable_cli=0 ${SOURCE_DIR}/n98-magerun2.phar --root-dir=${PROJECT_WEBROOT}"


# 1 day
echo "Checking age ..."
MAX_AGE=86400

NOW=`date +%s`


DB_CREATED=`cat ${SYSTEMSTORAGE_LOCAL}/database/created.txt`
AGE_DB=$((NOW-DB_CREATED))
if [ "$AGE_DB" -lt "$MAX_AGE" ] ; then echo "DB age ok (${AGE_DB} sec)" ; else error_exit "Age of the database dump is too old (1 day max)"; fi;


if [ -z "${SKIPFILES}" ] ; then
    FILES_CREATED=`cat ${SYSTEMSTORAGE_LOCAL}/files/created.txt`
    AGE_FILES=$((NOW-FILES_CREATED))
    if [ "$AGE_FILES" -lt "$MAX_AGE" ] ; then echo "Files age ok (${AGE_FILES} sec)"; else error_exit "Age of the files dump is too old (1 day max)"; fi;
fi



# Importing database...
echo "Dropping all tables"
$n98 -q db:drop --tables --force || error_exit "Error while dropping all tables"


echo "Import database dump ${SYSTEMSTORAGE_LOCAL}/database/combined_dump.sql.gz"
$n98 -q db:import --compression=gzip "${SYSTEMSTORAGE_LOCAL}/database/combined_dump.sql.gz" ||  error_exit "Error while importing dump"

echo
echo "Applying settings"
echo "-----------------"
cd "${PROJECT_WEBROOT}" || error_exit "Error while switching to htdocs directory"
if [ ! -f vendor/aoepeople/zettr/zettr.phar ]; then
    error_exit "Zettr.phar is missing"
fi
vendor/aoepeople/zettr/zettr.phar apply ${ENVIRONMENT} config/settings.csv  || error_exit "Error while applying settings"
echo


# Importing files...
if [ -z "${SKIPFILES}" ] ; then
    echo "Copy media folder"
    rsync \
    --archive \
    --force \
    --no-o --no-p --no-g \
    --omit-dir-times \
    --ignore-errors \
    --partial \
    --exclude=/catalog/product/cache/ \
    --exclude=/tmp/ \
    --exclude=.svn/ \
    --exclude=*/.svn/ \
    --exclude=.git/ \
    --exclude=*/.git/ \
    "${SYSTEMSTORAGE_LOCAL}/files/" "${PROJECT_WEBROOT}/pub/media/"
fi
