#!/bin/bash
# this is where all the common functions are kept.

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#echo "dsCommon says libdir= $LIBDIR"



#were the prefs file is
PREFS_FILE=$LIBDIR/../prefs/server-sfm.prefs

### echo functions for different colors etc.

function echoGood () {
#echos green text to stand out for succesful execution of a task
#      ... hmmm default os x terminal is green text...
INPUT_TEXT=$1
printf "\e[0;32m${INPUT_TEXT}\e[0m\n"
}

function echoBad () {
#echos red text to stand out for a fail/warning
INPUT_TEXT=$1
printf "\e[0;31m${INPUT_TEXT}\e[0m\n"
}


### preferences functions for reading and setting preferences

function readPrefs () {
#echo "reading pref $1"
PREF_ITEM=$1
LINE_NUMBER=$(sed -n /"$PREF_ITEM"/= $PREFS_FILE)
if [[ $LINE_NUMBER -lt 1 ]] ; then echo "`echoBad ERROR` Pref: \"$PREF_ITEM\" can't be read" ; break ; else
((LINE_NUMBER++))
PREF_OUTPUT=$(sed -n "$LINE_NUMBER"p $PREFS_FILE)
PREF_OUTPUT=$(expand_tilde $PREF_OUTPUT)
fi

#lame check for spaces, if you need to do this more then just check
if [[ $PREF_ITEM -ne "clientNames" ]]
	then
		echo $PREF_OUTPUT
	else
		PREF_OUTPUT=`echo $PREF_OUTPUT | sed 's/,/ /g'`
		echo $PREF_OUTPUT
fi
}

function editPrefs () {

PREF_ITEM="#$1"
echo "PREF_ITEM = $PREF_ITEM"
PREF_SETTING=$(expand_tilde $2)
#LINE_NUMBER=$(sed -n '/#$PREF_ITEM/=' $PREFS_FILE)
LINE_NUMBER=$(sed -n /"$PREF_ITEM"/= $PREFS_FILE)
if [[ $LINE_NUMBER -lt 1 ]] ; then echo "`echoBad ERROR` Pref: \"$PREF_ITEM\" can't be set" ; break ; else
((LINE_NUMBER++))
awk -v line=$LINE_NUMBER -v new_content="$PREF_SETTING" '{
        if (NR == line ) {
                print new_content;
        } else {
                print $0;
        }
}' $PREFS_FILE > .tmp
mv .tmp $PREFS_FILE 
fi
}


#### file name operations
function expand_tilde()
{
    case "$1" in
    (\~)        echo "$HOME";;
    (\~/*)      echo "$HOME/${1#\~/}";;
    (\~[^/]*/*) local user=$(eval echo ${1%%/*})
                echo "$user/${1#*/}";;
    (\~[^/]*)   eval echo ${1};;
    (*)         echo "$1";;
    esac
}


#############################
### array functions

function remove {
  if [[ $1 =~ ([[:digit:]])(-([[:digit:]]))?   ]]; then
    from=${BASH_REMATCH[1]}
    to=${BASH_REMATCH[3]}
  else
    echo bad range
  fi;shift
  array=( ${@} )
  local start=${array[@]::${from}}
  local rest
  [ -n "$to" ] && rest=${array[@]:((${to}+1))}  || rest=${array[@]:((${from}+1))}
  echo ${start[@]} ${rest[@]}

## ussage
##yourArray=( `remove 2 ${yourArray[*]}` )
##echo ${yourArry[@]}

}

function getLocalIP () {

OPERATING_SYSTEM=$(uname)

	case $OPERATING_SYSTEM in
        Darwin)        
					for i in {0..2} ;
				        do
					        j=`ipconfig getifaddr en$i`       
			                if [ -z "$j" ]
        		                then
            	            :
                		        else addr=$j
                			fi
        			done
		;;
		Linux)
					addr=$(hostname -I)
		;;
	esac

echo $addr
}

function resolveNameFromIP () {
IP=$1
host $IP | awk -F'pointer' '{print $2}' | sed 's/\.//'
}

function pauseWarning () {

echo "Hit `echoGood ENTER` to continue, or `echoBad CTRL-C` to exit"
printf ">"
read nothing
}


#### progress bar ####

ProgressBar () {

COMMENT=$3
COLUMNS=$(tput cols)
((COLUMNS--))
CURRENT_POS=$1
TOTAL=$2

if [[ $CURRENT_POS -gt 1 || $TOTAL -gt 1 ]]
then

	COLUMNS_FACTOR=$( echo "scale = 5 ; $COLUMNS / $TOTAL " |bc )
	OUTPUT_POS=$( echo "scale = 5; $CURRENT_POS * $COLUMNS_FACTOR" | bc )
	OUTPUT_POS=${OUTPUT_POS%.*}
	((OUTPUT_POS++))

	SUB_POS=$(( COLUMNS - OUTPUT_POS  ))
	((SUB_POS++))
	#echo $OUTPUT_POS $SUB_POS
	if [[ "$OUTPUT_POS" -eq "0" || "$SUB_POS" -lt "1" ]]
		then 
			echo "### done ###"
		else
	#		RepeatChar "#" $OUTPUT_POS ; RepeatChar "-" $SUB_POS ; printf "\r"
			RepeatChar "█" $OUTPUT_POS ; RepeatChar "░" $SUB_POS ; printf "\r"
	#█░
			PERCENT=$( echo "scale = 3; ( $OUTPUT_POS / $COLUMNS ) * 100" | bc )
			PERCENT=${PERCENT%.*}
		printf "$PERCENT %%\r"
	fi
	sleep .1
fi
}

RepeatChar () {
    seq  -f $1 -s '' $2
}

#### Match Total Test #########
# 
# GetCurrentMatchProgress () {
# 
# VSFM_Path=$( which VisualSFM )
# VSFM_Dir=${VSFM_Path%/VisualSFM}
# current_VSFM_Log="$VSFM_Dir/log/"$( ls -1aqtr $VSFM_Dir/log | tail -1 )
# #echo "Current log is : $current_VSFM_Log"
# totalInMatchLog=$( cat $current_VSFM_Log | grep "pairs to compute match" | awk '{print $1}')
# #echo "totalInMatchLog is " $totalInMatchLog 
# 
# currentMatchTotal=$(awk '!/^#.*matches/{m=gsub("matches","");total+=m}END{print total}' $current_VSFM_Log)
# ((currentMatchTotal--))
# echo $currentMatchTotal $totalInMatchLog
# 
# }
