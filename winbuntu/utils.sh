#!/bin/bash

function genSymlinks () {
	local SYMLINKS=$1
	local TARGET_PATH=$2

	# bash config is difference between macOS and ubuntu.
	[[ $SYMLINKS =~ bash ]] && return

	for FILE_PATH in ~/.cider/symlinks/${SYMLINKS} ; do
		[[ ! -f ${FILE_PATH} ]] && continue
		IFS='/' read -r -a array <<< ${FILE_PATH}
		local FILE_NAME=${array[-1]}
		local TARGET=${TARGET_PATH}/${FILE_NAME}

		bash -c "test -e ${TARGET} && rm -f ${TARGET}"
		bash -c "ln -s ${FILE_PATH} ${TARGET}"
	done
}
