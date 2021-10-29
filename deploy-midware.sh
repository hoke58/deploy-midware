#!/bin/bash -e
#***************************************************************
#Desc: Universal Operation Console                             *
#      entry point for all components                          *
#createdBy: Hoke - 2021/06/15                                  *
#***************************************************************
clear

export mainShellPath=$(dirname `readlink -f ${BASH_SOURCE[0]}`)

consoleInit(){
 source ${mainShellPath}/cfg/common.cfg
 source ${mainShellPath}/cfg/dynamic.cfg
 source ${mainShellPath}/libs/bin/00_common_functions.sh
 source ${mainShellPath}/libs/bin/01_displayMainMenu.sh
}

function main(){
   consoleInit
   displayMainMenu
}
main
