#!/usr/bin/env bash

function usage {
    echo "Usage:"
    echo " $0 -f <packageFilename> -b <buildNumber> [-g <gitRevision>] [-r <projectRootDir>]"
    echo " -f <packageFilename>    file name of the archive that will be created"
    echo " -b <buildNumber>        build number"
    echo " -g <gitRevision>        git revision"
    echo " -r <projectRootDir>     Path to the project dir. Defaults to current working directory."
    echo ""
    exit $1
}

PROJECTROOTDIR=$PWD

########## get argument-values
while getopts 'f:b:g:d:r:' OPTION ; do
case "${OPTION}" in
        f) FILENAME="${OPTARG}";;
        b) BUILD_NUMBER="${OPTARG}";;
        g) GIT_REVISION="${OPTARG}";;
        r) PROJECTROOTDIR="${OPTARG}";;
        \?) echo; usage 1;;
    esac
done

if [ -z ${FILENAME} ] ; then echo "ERROR: No file name given (-f)"; usage 1 ; fi
if [ -z ${BUILD_NUMBER} ] ; then echo "ERROR: No build number given (-b)"; usage 1 ; fi

cd ${PROJECTROOTDIR} || { echo "Changing directory failed"; exit 1; }

if [ ! -f 'composer.json' ] ; then echo "Could not find composer.json"; exit 1 ; fi
if [ ! -f 'bin/composer.phar' ] ; then echo "Could not find composer.phar"; exit 1 ; fi

if type "hhvm" &> /dev/null; then
    PHP_COMMAND=hhvm
    echo "Using HHVM for composer..."
else
    PHP_COMMAND=php
fi

# Run composer
$PHP_COMMAND bin/composer.phar install --verbose --no-ansi --no-interaction --prefer-source || { echo "Composer failed"; exit 1; }

# Some basic checks
if [ ! -f 'pub/index.php' ] ; then echo "Could not find pub/index.php"; exit 1 ; fi

# Write file: build.txt
echo "${BUILD_NUMBER}" > build.txt

# Write file: version.txt
echo "Build: ${BUILD_NUMBER}" > pub/version.txt
echo "Build time: `date +%c`" >> pub/version.txt
if [ ! -z ${GIT_REVISION} ] ; then echo "Revision: ${GIT_REVISION}" >> pub/version.txt ; fi

# Create package
if [ ! -d "artifacts/" ] ; then mkdir artifacts/ ; fi

tmpfile=$(tempfile -p build_tar_base_files_)

# Backwards compatibility in case tar_excludes.txt doesn't exist
if [ ! -f "config/tar_excludes.txt" ] ; then
    touch config/tar_excludes.txt
fi

BASEPACKAGE="artifacts/${FILENAME}"
echo "Creating base package '${BASEPACKAGE}'"
tar -vczf "${BASEPACKAGE}" \
    --exclude=./var \
    --exclude=./pub/media \
    --exclude=./artifacts \
    --exclude=./tmp \
    --exclude-from="config/tar_excludes.txt" . > $tmpfile || { echo "Creating archive failed"; exit 1; }

EXTRAPACKAGE=${BASEPACKAGE/.tar.gz/.extra.tar.gz}
echo "Creating extra package '${EXTRAPACKAGE}' with the remaining files"
tar -czf "${EXTRAPACKAGE}" \
    --exclude=./var \
    --exclude=./pub/media \
    --exclude=./artifacts \
    --exclude=./tmp \
    --exclude-from="$tmpfile" .  || { echo "Creating extra archive failed"; exit 1; }

rm "$tmpfile"

cd artifacts
md5sum * > MD5SUMS