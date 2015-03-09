#!/bin/sh
DIALOG=${DIALOG=dialog}
tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
trap "rm -f $tempfile" 0 1 2 5 15
source ~/sfm/server_sfm/server-sfm.lib
$DIALOG --clear --title "My  favorite HINDI singer" \
        --menu "Hi, Choose  your favorite HINDI singer:" 20 51 40 \
"BenchmarkMatch" "BenchmarkMatch" \
"testCommandLocal" "testCommandLocal" \
"beginCMVSdistribution" "beginCMVSdistribution" \
"reconstructSFM" "reconstructSFM" \
"initVars"  "initVars" \
"initVars_sh_server"  "initVars_sh_server" \
"initRm"  "initRm" \
"initDirs"  "initDirs" \
"initClientDirs"  "initClientDirs" \
"chooseNumberOfServers"  "chooseNumberOfServers" \
"getImgList"  "getImgList" \
"assignIPRange"  "assignIPRange" \
"serverIDs"  "serverIDs" \
"realServerCreation"  "realServerCreation" \
"initRemoteServers"  "initRemoteServers" \
"fakeServerCreation"  "fakeServerCreation" \
"copyImagesToRealServers"  "copyImagesToRealServers" \
"copyImagesToFakeServers"  "copyImagesToFakeServers" \
"siftListsPerServer"  "siftListsPerServer" \
"copyListsToRealServers"  "copyListsToRealServers" \
"copyListsToFakeServers"  "copyListsToFakeServers" \
"startRealSifts"  "startRealSifts" \
"startFakeSifts"  "startFakeSifts" \
"waitForSiftsToFinish"  "waitForSiftsToFinish" \
"getInverseSifts"  "getInverseSifts" \
"waitForSiftsToCopy"  "waitForSiftsToCopy" \
"getMatchListTotal"  "getMatchListTotal" \
"makeMatchLists"  "makeMatchLists" \
"startMatchesOnServers"  "startMatchesOnServers" \
"waitForMatchesToExport"  "waitForMatchesToExport" \
"copyFakeSiftsToHosts"  "copyFakeSiftsToHosts" \
"combineMatch"  "combineMatch" \
"function copyMatchesToRealServers"  "function copyMatchesToRealServers" \
"copyMatchesToFakeServers"  "copyMatchesToFakeServers" \
"disconnectAllServers"  "disconnectAllServers" \
"reconstructSFM"  "reconstructSFM" \
"beginCMVSdistribution"  "beginCMVSdistribution" \
"copyBackGlob"  "copyBackGlob" \
"scpTo"  "scpTo" \
"scpToCueIp"  "scpToCueIp" \
"scpHome"  "scpHome" \
"writeIPInstanceID"  "writeIPInstanceID" \
"archiveImages"  "archiveImages" 2> $tempfile

retval=$?

choice=`cat $tempfile`

case $retval in
  0)
  	 clear 
     echo "'$choice' is your command - hit ENTER or ctrl-c to cancel";
     read nothing;
     if [ $nothing -z ]
     then 
     $choice
     else 
     	echo "canceled at last minute"
     fi;;     
  1)
    echo "Cancel pressed.";;
  255)
    echo "ESC pressed.";;
esac
