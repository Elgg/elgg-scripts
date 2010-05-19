#!/bin/bash

# takes a target and version number
SVN_BASE_URL="http://code.elgg.org/"
OUTPUT_DIR="./"
TMP_DIR="/tmp/"
SVN_EXEC=$(which svn)
ZIP_EXEC=$(which zip)
TAR_EXEC=$(which tar)
SVN2CL_EXEC=$(which svn2cl)

VERBOSE=1

#############
# FUNCTIONS #
#############

# sanity check and init
init() {
	if [ ${#} -lt 2 ]; then
		usage
		exit 1
	fi

	SVN_URL="${SVN_BASE_URL}${1}"
	RELEASE=${2}

	# get output and tmp dirs
	if [ ${#} -gt 2 ]; then
		OUTPUT_DIR=$(echo "${3}" | sed 's/\/$//')
		OUTPUT_DIR="${OUTPUT_DIR}/"
	fi

	if [ ${#} -gt 3 ]; then
		TMP_DIR=$(echo "${4}" | sed 's/\/$//')
		TMP_DIR="${TMP_DIR}/"
	fi

	# check write permissions
	if [ ! -d ${OUTPUT_DIR} -o ! -w ${OUTPUT_DIR} ]; then	
		usage "output_dir \"${OUTPUT_DIR}\" does not exist or is not writable!"
		exit 1
	fi

	if [ ! -d ${TMP_DIR} -o ! -w ${TMP_DIR} ]; then
		usage "tmp_dir \"{$TMP_DIR}\" does not exist or is not writable!"
		exit 1
	fi

	if [ "${SVN_EXEC}" = "" ]; then
		echo "Could not find an SVN executable in the path!"
		exit 1
	fi

	if [ "${ZIP_EXEC}" = "" ]; then
		echo "Could not find a zip executable in the path!"
		exit 1
	fi

	if [ "${TAR_EXEC}" = "" ]; then
		echo "Could not find a tar executable in the path!"
		exit 1
	fi

	DATE=$(date +%s)
	BASE_NAME="elgg-${RELEASE}"
	TMP_DIR="${TMP_DIR}${DATE}/"
	SVN_EXPORT_PATH="${TMP_DIR}${BASE_NAME}"
}

cleanup() {
	run_cmd "rm -rf ${TMP_DIR}"
}

prep_svn() {
	msg "Exporting SVN..."
	run_cmd "${SVN_EXEC} export ${SVN_URL} ${SVN_EXPORT_PATH}"

	if [ $? -gt 0 ]; then
		echo "Could export ${SVN_URL} to ${SVN_EXPORT_PATH}!"
		echo "Check that the target exists and try again."
		exit 1
	fi

	run_cmd "${SVN2CL_EXEC} --group-by-day -o ${SVN_EXPORT_PATH}/ChangeLog ${SVN_URL}"

	if [ $? -gt 0 ]; then
		echo "Could export generate ChangeLog for ${SVN_EXPORT_PATH}!"
		echo "Check that the target exists and try again."
		exit 1
	fi
}

make_archives() {
	#make_tar_archive
	make_zip_archive
}

make_tar_archive() {
	msg "Building tar archive..."

	NAME="${BASE_NAME}.tar.gz"
	run_cmd "cd ${TMP_DIR}"
	run_cmd "${TAR_EXEC} zcvf ${NAME} ${BASE_NAME}"
	run_cmd "cd -"
	run_cmd "cp ${TMP_DIR}${NAME} ${OUTPUT_DIR}"
}

make_zip_archive() {
	msg "Building zip archive..."

	NAME="${BASE_NAME}.zip"
	run_cmd "cd ${TMP_DIR}"
	run_cmd "${ZIP_EXEC} -r ${NAME} ${BASE_NAME}"
	run_cmd "cd -"
	run_cmd "cp ${TMP_DIR}${NAME} ${OUTPUT_DIR}"
}

run_cmd() {
	if [ ${#} -gt 0 ]; then
		msg "${1}" 2
		if [ ${VERBOSE} -gt 1 ]; then
			${1}
		else
			${1} > /dev/null 2>&1
		fi

		return $?
	fi

	return 1
}

# Show how to use this script
usage() {
	echo "Usage: ${0} target_name version [output_dir = './' [temp_dir = '/tmp']]"
	echo ""
	echo "Where target_name is the path of the SVN dir to export and"
	echo "version is the version name for the archive."
	echo ""
	echo "Generates output_dir/elgg-version.tar.gz and output_dir/elgg-version.zip"
	echo ""
	echo "Examples:"
	echo "${0} elgg/trunk trunk-nightly"
	echo "${0} elgg/branches/1.7 1.7-nightly"
	echo "${0} elgg/tags/1.7 1.7 /var/www/downloads/releases/"

	if [ ${#} -gt 0 ]; then
		echo ""
		echo "Error: $1"
	fi
}

msg() {
	LEVEL=1
	if [ ${#} -gt 1 ]; then
		LEVEL=${2}
	fi

	if [ ${VERBOSE} -ge ${LEVEL} ]; then
		echo "${1}"
	fi
}


########
# Work #
########

init $@

prep_svn

make_archives

cleanup

msg "Done!"
