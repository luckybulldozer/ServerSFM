#!/bin/bash
# main function process to execute ServerSFM executing from ec2-sfm.lib

#known functions and execution order to be added.

# all launcher apps need to have this to start

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#echo "Installer says libdir= $LIBDIR"
source $LIBDIR/dsCommon.lib.sh
source $LIBDIR/server-sfm.lib.sh

#INIT ROUTINES
#check in a directory that contains .jpg/.JPG data.  
sanityCheck

#inits local and intermachine variables for paths etc, needs to be turned on for most testing.
initVars 

#display Prefs read from locally assigned variables.
displayPrefs

#clears directories so you start fresh... could do with some alteration/options
initRm

#gets all jpegs in the current directory for the SFM session.
getImgList

#
assignClientRange

purgeFilesInRemoteProcessingDirectories

#40
clientInit

#50
copyImagesToRealServers
#copyImagesToFakeServers
#60
siftListsPerServer
#70
copyListsToServers
#copyListsToFakeServers

# START SIFT ON SERVERS

#80
startSifts
#startFakeSifts
#90
waitForSiftsToFinish


#100
getInverseSifts


#110
waitForSiftsToCopy

# START MATCH ON SERVERS

#120
getMatchListTotal
BenchmarkMatch
#130
#makeMatchLists #or BenchmarkMatch
#140
startMatchesOnServers
#150
waitForMatchesToExport
#160
combineMatch
#170
copyMatchesToBackHomeToClients
#copyMatchesToFakeServers
#180



startLocalSFM

copyCMVSDirToServers

#clearAllJobs

determinePMVS_JOBS

preparePMVS_Jobs

startPMVS_Sender


#CONSIDER MATCHES

#REDISTUBITE VSFMS

#COMBINE VSFMs

#PMVS STAGE



#vsfmMatchImages


### eg a sift looper;
#waitForMatchesToFinish
#exportMatchesFromServer

#waitForMatchesToFinish
#exportMatchesFromServer
