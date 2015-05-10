#!/bin/bash
# this is where all the common functions are kept.

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#echo "dsCommon says libdir= $LIBDIR"



#were the prefs file is
PREFS_FILE=$LIBDIR/../prefs/server-sfm.prefs

#sanity check to see if in an image directory 

sanityCheck () {

ls -1 | grep -i "JPG"  > /dev/null 2>&1
if [ $? -ne 0 ]
	then
		echo ""
		echoBad "Your current directory contains NO IMAGES!!! This software is potentially destructive; only operate on directories of images that you know are backed up somewhere else.  Please cd to another directory.  ServerSFM only works with images appended with .jpg or .JPG, not .jpeg or .JPEG or any other image formats."
		echo ""
		exit 1
fi

}



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

function echoAlert () {
INPUT_TEXT=$1
echo ""
echo "$(tput setaf 0)$(tput setab 3)$INPUT_TEXT$(tput sgr 0)"

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

#echo "Hit `echoGood ENTER` to continue, or `echoBad CTRL-C` to exit"
echoAlert "Hit ENTER to continue, or CTRL-C to exit"
printf ">"
read nothing
}


#### progress bar ####

ProgressBar () {

COMMENT=$3
COLUMNS=$(tput cols)
((COLUMNS--))
CURRENT_POS=${1%.*}
TOTAL=${2%.*}

if [ "$TOTAL" -gt 0 ] 
then  

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
			:
			#	echo "### done ###"
			else
		#		RepeatChar "#" $OUTPUT_POS ; RepeatChar "-" $SUB_POS ; printf "\r"
				RepeatChar "█" $OUTPUT_POS ; RepeatChar "░" $SUB_POS ; printf "\r"
		#█░
#	echo Output Position : $OUTPUT_POS Sub Posistion $SUB_POS

				PERCENT=$( echo "scale = 3; ( $OUTPUT_POS / $COLUMNS ) * 100" | bc )
				PERCENT=${PERCENT%.*}
			if [ -z $PERCENT ]
			then
				tput sgr 0
				printf "0"			
			fi
			printf "$PERCENT %%\r"
		fi
		sleep .1
	fi
fi
}

RepeatChar () {
    seq  -f $1 -s '' $2
}


################# multiProgressBar ####################

multiProgressBar () {

#echo machines to divide : $# arg: $@
#read nothing
machines=$(( $# / 2 ))
#echo "machines = $machines numArgs $# args $@"
checkComment=$(( $# % 2 ))
if [[ "$checkComment" -eq 1 ]]
        then commentField=$1
        #echo "comment is : $commentField"
fi

lineEntry=$(tput lines)
((lineEntry--))
lineEntry=$(( lineEntry - machines  ))
lineEntry2=$((lineEntry + 2 ))

#machines tputDiff=$(( lineEntry2 - lineEntry  ))
for (( i = 1 ; i <= machines ; i++ ))
        do
                ((lineEntry--))
                ((lineEntry2--))
        done


printf "\033[<${lineEntry}>;<0>f" # goto lineEntry 53
#echo "                          $Comment"
#echo 
printf "\033[<${lineEntry2}>;<0>f" #goto lineEntry2 (55
#printf "\033[<${lineEntry2}>;<0>f" #goto lineEntry2 (55

count=0

for var in $@
        do
            allVars[$count]=$var
            ((count++))
        done

minorSum=0
majorSum=0

count=0
for (( i = 0 ; i < $machines ; i++ ))
        do
                subCount=$(( count + 1 ))
                ProgressBar ${allVars[$count]} ${allVars[$subCount]} ; echo
                minor=${allVars[$count]}
                major=${allVars[$subCount]}
                minorSum=$((minorSum + minor))
                majorSum=$((majorSum + major))
                ((count++));((count++))
        done

if [[ "$majorSum" -ne 0 ]] 
then 
ProgressBar $minorSum $majorSum #; echo
fi

}

# prob dont need this at the moment.
getCursorPosition () {
# based on a script from http://invisible-island.net/xterm/xterm.faq.html
# thanks denniswilliamson.us
exec < /dev/tty
oldstty=$(stty -g)
stty raw -echo min 0
# on my system, the following line can be replaced by the line below it
echo "\033[6n" > /dev/tty
# tput u7 > /dev/tty    # when TERM=xterm (and relatives)
IFS=';' read -r -d R -a pos
stty $oldstty
# change from one-based to zero based so they work with: tput cup $row $col
row=$((${pos[0]:2} - 1))    # strip off the esc-[
col=$((${pos[1]} - 1))

echo $row 

}


### rm working dir case block

function initRmCase () {

echo ""
echoBad "About to rm most NON jpeg files in $SOURCE_IMAGE_DIR."
echoGood "(just keep only your jpegs in here, and you should still have a BACK UP!)"

echoAlert "Hit ENTER to delete non-jpeg data / L to list / Q to quit"
printf ">"
read rmInitPrompt

enter=`printf "\n"`

rmInitPrompt=$( tr '[:upper:]' '[:lower:]' <<<"$rmInitPrompt" )
case $rmInitPrompt in
        l)
                echoGood "Contents of current directory"
                ls 
                 
		  initRmCase
                ;;
        q)
                echo "Exiting..."
                exit 1
                ;;
        $enter)
		#echo "you hit the ENTER Key"
		echo "Deleting everything in directory except JPGs"
		;;
	*)
        	echo "Invalid choice"    
		initRmCase
esac
}


#######################################################

function remoteRmCase () {

REMOTE_CLIENT_TO_RM="$1"
if [[ -z $REMOTE_CLIENT_TO_RM ]] 
	then
		echo "Exiting due to unset variable"
		exit 1
	fi

enter=`printf "\n"`


echoBad "About to delete ALL contents of remote directory $REMOTE_CLIENT_TO_RM"

echoAlert "Hit ENTER to delete temp dir on $REMOTE_CLIENT_TO_RM / L to list / Q to quit"
printf ">"
read rmRemotePrompt



rmRemotePrompt=$( tr '[:upper:]' '[:lower:]' <<<"$rmRemotePrompt" )
case $rmRemotePrompt in
        l)
                ssh -i $SSH_KEY $SFM_USERNAME@$REMOTE_CLIENT_TO_RM "ls $JOB_LOCATION*" 
                echo "Hit ENTER to continue." 
		  remoteRmCase $REMOTE_CLIENT_TO_RM
                ;;
        q)
                echo "Exiting..."
                exit 1
                ;;
        $enter)
				echo "Deleting everything in directory except JPGs"
		;;
	*)
        	echo "Invalid choice"    
		remoteRmCase $REMOTE_CLIENT_TO_RM
		;;
esac
}



#######################################################






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
