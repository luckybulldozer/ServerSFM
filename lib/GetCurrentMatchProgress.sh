#!/bin/sh

#GetCurrentMatchProgress () {

VSFM_Path="/Users/dmonaghan/sw/vsfm/bin/VisualSFM"
VSFM_Dir=${VSFM_Path%/VisualSFM}
current_VSFM_Log="$VSFM_Dir/log/"$( ls -1aqtr $VSFM_Dir/log | grep log | tail -1 )
#echo "Current log is : $current_VSFM_Log"
totalInMatchLog=$( cat $current_VSFM_Log | grep "pairs to compute match" | awk '{print $1}')
#echo "totalInMatchLog is " $totalInMatchLog 

currentMatchTotal=$(awk '!/^#.*matches/{m=gsub("matches","");total+=m}END{print total}' $current_VSFM_Log)
((currentMatchTotal--))
if [ "$currentMatchTotal" -lt 1 ]
	then currentMatchTotal=0
fi

if [[ -z "$totalInMatchLog"  ]]
	then totalInMatchLog=0
fi

echo $currentMatchTotal $totalInMatchLog

#}
