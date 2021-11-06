#!/bin/bash

function genSymlinks () {
  local SYMLINKS=$1
  local TARGET_PATH=$2

  # bash config is difference between macOS and ubuntu.
  [[ $SYMLINKS =~ bash ]] && return

  for FILE_PATH in ~/.cider/symlinks/${SYMLINKS} ; do
    [[ ! -e ${FILE_PATH} ]] && continue
    local ARRAY=($(echo ${FILE_PATH} | tr "/" "\n"))
    local IDX=${#ARRAY[@]}
    local FILE_NAME=${ARRAY[$IDX - 1]}

    [[ ${FILE_NAME} == "." ]] && continue
    [[ ${FILE_NAME} == ".." ]] && continue

    if [[ ${SYMLINKS} == */ ]]
    then
      local TARGET=${TARGET_PATH}
      bash -c "test -d ${TARGET_PATH}/${FILE_NAME} && rm -rf ${TARGET_PATH}/${FILE_NAME}"
    else 
      local TARGET=${TARGET_PATH}/${FILE_NAME}
      bash -c "test -e ${TARGET} && rm -f ${TARGET}"
    fi

    bash -c "ln -s ${FILE_PATH} ${TARGET}"
  done
}
