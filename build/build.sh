#!/bin/bash

# takes a target and version number
GIT_REPO_URL="git://github.com/Elgg/Elgg.git"
TMP_DIR="/tmp/"
GIT_EXEC=$(which git)
ZIP_EXEC=$(which zip)
TAR_EXEC=$(which tar)
COMPOSER_EXEC=$(which composer)

PWD=`pwd`
OUTPUT_DIR="${PWD}/"

# erm...http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
EXEC_DIR="$( cd "$( dirname "$0" )" && pwd )"
GIT2CL_EXEC="${EXEC_DIR}/gitlog2changelog.py"

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

	BRANCH=${1}
	RELEASE=${2}

	# is this an mit release
	MIT=false
	if [[ "$RELEASE" == *mit* ]]; then
		echo "MIT release"
		MIT=true
	fi

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

	if [ "${GIT_EXEC}" = "" ]; then
		echo "Could not find an GIT executable in the path!"
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

        if [ "${COMPOSER_EXEC}" = "" ]; then
		echo "Could not find a composer executable in the path!"
		exit 1
	fi

	DATE=$(date +%s)
	BASE_NAME="elgg-${RELEASE}"
	TMP_DIR="${TMP_DIR}${DATE}/"
	GIT_CLONE_PATH="${TMP_DIR}${BASE_NAME}"
	RUN_DIR=`pwd`
}

cleanup() {
	run_cmd "rm -rf ${TMP_DIR}"
}

prep_git() {
	msg "Cloning ${GIT_REPO_URL}..."
	run_cmd "${GIT_EXEC} clone ${GIT_REPO_URL} ${GIT_CLONE_PATH}"

	if [ $? -gt 0 ]; then
		echo "Could not clone ${GIT_REPO_URL} to ${GIT_CLONE_PATH}!"
		echo "Check that the target exists and try again."
		exit 1
	fi
	
	# checkout the right branch
	run_cmd "cd ${GIT_CLONE_PATH}"
	run_cmd "git checkout ${BRANCH}"
	if [ $? -gt 0 ]; then
		echo "Could not check out branch ${BRANCH}"
		echo "Check that the branch / tag is valid and try again."
		exit 1
	fi
	
	#run_cmd ${GIT2CL_EXEC}
	${GIT2CL_EXEC}

	if [ $? -gt 0 ]; then
		echo "Could not generate ChangeLog for ${GIT_CLONE_PATH}!"
		echo "Check that the target exists and try again."
		exit 1
	fi
	
	# don't package the .git dir or .gitignore files
	run_cmd "rm -rf ${GIT_CLONE_PATH}/.git*"
	run_cmd "rm -rf `find ${GIT_CLONE_PATH} -name .gitignore`"
	run_cmd "rm -f ${GIT_CLONE_PATH}/.travis.yml"
	
	if [ $? -gt 0 ]; then
		echo "Could not remove the .git files!"
		exit 1
	fi

	# MIT release handling
	if $MIT ; then
		echo "Doing MIT preparations"
		run_cmd "rm -f ${GIT_CLONE_PATH}/LICENSE.txt"
		run_cmd "cp ${RUN_DIR}/MIT_LICENSE.txt ${GIT_CLONE_PATH}/LICENSE.txt"
		run_cmd "rm -rf ${GIT_CLONE_PATH}/mod/*"

		if [ $? -gt 0 ]; then
			echo "Failed making the MIT release modifications"
			exit 1
		fi
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

fix_perms() {
	run_cmd "cd ${TMP_DIR}"
	run_cmd "find ./ -type f -exec chmod 644 {} +"
	run_cmd "find ./ -type d -exec chmod 755 {} +"
	run_cmd "cd -"
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
	echo "Usage: ${0} <identifier> <version> [output_dir = './' [temp_dir = '/tmp']]"
	echo ""
	echo "Where <identifier> is the path of the GIT dir to export and"
	echo "<version> is the version name for the archive."
	echo "If <version> contains the letters mit, an MIT release is made. Example: 1.8.14-mit"
	echo ""
	echo "Generates output_dir/elgg-version.zip"
	echo ""
	echo "Examples:"
	echo "${0} master trunk-nightly"
	echo "${0} 1.7 1.7-nightly"
	echo "${0} 1.7.0 1.7.0 /var/www/www.elgg.org/download/"

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

composer_install() {

    if [ ! -f "${GIT_CLONE_PATH}/composer.json" ]; then
        # composer.json doesn't exist
        # no need to run composer, this is an older Elgg version
        return 1
    fi

    msg "Installing vendors with composer..."

    run_cmd 'composer install'

    if [ $? -gt 0 ]; then
	echo "Could not complete composer install"
	exit 1
    fi
}


########
# Work #
########

init $@

prep_git

composer_install

fix_perms

make_archives

cleanup

msg "Done!"
