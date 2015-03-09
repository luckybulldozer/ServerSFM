#!/bin/bash
# this is where all the common functions are kept.

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
echo "dsCommon says libdir= $LIBDIR"



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




