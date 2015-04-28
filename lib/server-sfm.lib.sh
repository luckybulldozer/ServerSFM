#!/bin/bash
# server-sfm.lib

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
#echo "Installer says libdir= $LIBDIR"
source $LIBDIR/dsCommon.lib.sh

echoGood "                                     _____ ________  ___   "
echoGood "     ________  ______   _____  _____/ ___// ____/  |/  /   "
echoBad "    / ___/ _ \/ ___/ | / / _ \/ ___/\__ \/ /_  / /|_/ /    "
echoBad "   (__  )  __/ /   | |/ /  __/ /   ___/ / __/ / /  / /     "
echoGood "  /____/\___/_/    |___/\___/_/   /____/_/   /_/  /_/  0.1.0"
echo ""
echo "Booting SFM..."


initVars () {

#alter these three variables for your own configuration, may have an effect on the installer, so make sure you know what you are doing

#main ssh key that connects host to clients and vice versa, this is set in the installer
SSH_KEY=$(readPrefs sshKey)

#this is the username on ALL machines... will need to work out a new way to work under different names...
SFM_USERNAME=$(readPrefs username);

#location of the install archive which becomes the working directory.  
SSFM_INSTALL_DIR=$(readPrefs ssfmInstallDir)
echo ""
echoGood "Assigning SSFM_INSTALL_DIR to $SSFM_INSTALL_DIR"

#this is the same as the installer dir, to conform to legacy where the "render server" was located somewhere else, now we work in the install directory to ease a putting things all over the users computer.
SERVER_WORKDIR=$(readPrefs serverWorkDir)
echoGood "Assinging SERVER_WORKDIR to $SERVER_WORKDIR"


#local jpeg folder attributes
#
#where img_list.txt and matches/.matchtmp.txt is kept
IMG_LOG_DIR=$(readPrefs serverWorkDir)"/imglogdir"
#where .matchtmp.txt is kept
MATCH_LIST_DIR=$IMG_LOG_DIR/matches


#client "render server" attributes
#
#where the server lists clients
#SERVER_CLIENTS_LIST_DIR
SERVER_CLIENTS_LIST_DIR=$(readPrefs serverWorkDir)"/jobs/server/clients/have_launched"
SERVERS_CLIENT_LIST=$SERVER_WORKDIR"/jobs/server/clients/clientlist.txt"


#Directory on Clients where the images are worked on.
CLIENT_WORKDIR=$(readPrefs clientWorkDir)
CLIENT_IMAGE_DIR=$CLIENT_WORKDIR/task_processing/

# This is the main machine the script is executed on.
MASTER_SERVER=$(readPrefs masterServer)

#directory where script is executed (should only contain images!)
SOURCE_IMAGE_DIR=$PWD

# VisualSFM & PMVS names calculated from the folder we start the script in.
#
#vsfm project name
PROJECT_NAME=${SOURCE_IMAGE_DIR##*/}.nvm
#cmvs directory
CMVS_NAME=$PROJECT_NAME.cmvs

#Variables used for location of Jobs Cues on Clients
JOBS_SET=$(readPrefs serverWorkDir)"/jobs/server/set"
JOBS_DONE=$(readPrefs serverWorkDir)"/jobs/server/done"

#Host Idle Directory

HOSTS_ONLINE=$SERVER_WORKDIR/jobs/server/clients/idle/
#double up!
IDLE_DIR=$(readPrefs serverWorkDir)"/jobs/server/clients/idle"
BUSY_DIR=$(readPrefs serverWorkDir)"/jobs/server/clients/busy"
HAVE_LAUNCHED_DIR=$(readPrefs serverWorkDir)"/jobs/server/clients/have_launched"

#Jobs Cue locations
RENDER_SERVER=$SERVER_WORKDIR"/jobs/client/"
JOBS_PENDING=$RENDER_SERVER"/pending/"
JOBS_PROCESSING=$RENDER_SERVER"/processing/"
JOBS_COMPLETE=$RENDER_SERVER"/complete/"
JOBS_FAILED=$RENDER_SERVER"/failed/"
JOBS_SETUP=$RENDER_SERVER"/setup/"
JOBS_CUED=$RENDER_SERVER"/cued/"
JOB_LOCATION=$RENDER_SERVER"/task_processing/"
OUTPUT_FOLDER=$RENDER_SERVER"/completed/"

#Just here for checking readPrefs and editPrefs functions
TEST_PREF=$(readPrefs testPref)
}

displayPrefs() {
echo ""
echoBad "Displaying User Variables from prefs"
echoBad "SFM_USERNAME : $SFM_USERNAME"
echoBad "SSFM_INSTALL_DIR: $SSFM_INSTALL_DIR"
echoBad "IMG_LOG_DIR: $IMG_LOG_DIR"
echoBad "CLIENT_LIST_DIR: $CLIENT_LIST_DIR"
echoBad "SERVER_WORKDIR: $SERVER_WORKDIR"
echoBad "CLIENT_IMAGE_DIR: $CLIENT_IMAGE_DIR"
echoBad "TEST_PREF: $TEST_PREF"
echoBad "JOBS_DONE: $JOBS_DONE"
echoBad "JOBS_SET: $JOBS_DONE"
echoBad "PROJECT_NAME: $PROJECT_NAME"
echoBad "CMVS_NAME: $CMVS_NAME"

pauseWarning

}


initRm () {

echo ""
echoBad "About to rm pretty much all NON jpeg in $SOURCE_IMAGE_DIR."
echoGood "(just keep only your jpegs in here, and they should STILL be a back up!)"
ls -1 | sed '/[jJ][pP][gG]*$/d'

pauseWarning

#once working should take a lot more general approach
#$IMG_LOG_DIR/match*
rm -fr  $IMG_LOG_DIR/left_pair $IMG_LOG_DIR/right_pair $IMG_LOG_DIR/*clean_pair* $CLIENT_LIST_DIR $SOURCE_IMAGE_DIR/*sift* $SOURCE_IMAGE_DIR/match* $MATCH_LIST_DIR/.matchtmp.txt $SOURCE_IMAGE_DIR/got_sifts $SOURCE_IMAGE_DIR/*.mat $SOURCE_IMAGE_DIR/match* $SOURCE_IMAGE_DIR/*nvm* $SOURCE_IMAGE_DIR/siftlists/  $SOURCE_IMAGE_DIR/*.tar 

}

## This shouldn't be in here, just putting back to try and fix things!
initClientDirs () {
mkdir -pv $SFM_WORK_DIR/iplog $SFM_WORK_DIR/imglogdir/matches $SOURCE_IMAGE_DIR/siftlists
}

getImgList () {
									
ls -1 *.[jJ][Pp][Gg] > $IMG_LOG_DIR/img_list.txt
IMAGES=`wc -l $IMG_LOG_DIR/img_list.txt | awk '{print$1}'`
NUMBER_OF_IMAGES=$IMAGES

}


assignClientRange () {
#was far more complicated when starting up EC2 instances

#This is just inited from...
echoGood "Server List is:" 
ls -1 $HAVE_LAUNCHED_DIR
echo""
NUMBER_OF_SERVERS=$(ls -1 $HAVE_LAUNCHED_DIR | wc -l)

}

purgeFilesInRemoteProcessingDirectories () {

echoBad "About to rm all images in temporary client directories..."

for i in `ls -1 $HAVE_LAUNCHED_DIR`; do
	if [ -z $JOB_LOCATION ]
		then
			echo "failed to find \$JOB_LOCATION variable, this could be fatal" ; exit 1 ; 
		else
			ssh -i $SSH_KEY $SFM_USERNAME@$i "ls $JOB_LOCATION*"
			echo ""
			echo "Confirm remove `echoBad ALL` contents of this directory `echoGood y`/`echoBad N`?"
		 	printf ">"
		 	read delConfirm
		 		if [ -z $delConfirm ]
		 		then echoBad "Not deleting - exiting" ; exit 1 ; fi
		 		if [ $delConfirm == "y" ] 
		 			then 
		 				echo "About to delete directory contents"
						ssh -i $SSH_KEY $SFM_USERNAME@$i "rm -v $JOB_LOCATION*" 
						echoBad "gone..."
		 			else
		 				echoBad "Not deleting - exiting" ; exit 1 ;
		 		fi			 
		fi 		
done
}


clientInit () {
mkdir -p $SOURCE_IMAGE_DIR/siftlists
mkdir -p $SOURCE_IMAGE_DIR/imglogdir/matches
SERV_PLAN=`ls -1 $HAVE_LAUNCHED_DIR | wc -l`
SERV_ONLINE=`ls -1 $IDLE_DIR | wc -l`
echo ""
printf "Servers Scheduled: %03d Servers OnLine %02d. ." $SERV_PLAN $SERV_ONLINE     
#something wrong here if one host is still BUSY...
while [ "$SERV_ONLINE" -lt "$SERV_PLAN" ]
	do
	    #echo "Still not enought Servers launched..."
	    printf "\rServers Scheduled: %03d Servers OnLine %02d .." $SERV_PLAN $SERV_ONLINE
	    sleep .5
	    printf "\rServers Scheduled: %03d Servers OnLine %02d . " $SERV_PLAN $SERV_ONLINE     
	    SERV_ONLINE=`ls -1 ~/sfm/online_servers 2>/dev/null | wc -l`
done
echo ""
echo "looks like all Servers are Online!"

}

						initRemoteServers () {
echo "LS'n servers:"
for i in `ls -1 $HAVE_LAUNCHED_DIR` ;do 
# this line removes the ip from knownhosts to prevent a Spoof Login
    ssh-keygen -F "~/.ssh/known_hosts" -R $i
done

}


						 copyImagesToRealServers () {
echo "Tarrring images in source directory;"
tar cf imageArchive.tar --directory=$SOURCE_IMAGE_DIR/ *.[jJ][pP][gG]

echo "Listing servers that have launched;"
ls -1 $HAVE_LAUNCHED_DIR

#copy image set as archive to clients
for i in `ls -1 $HAVE_LAUNCHED_DIR`
	do 
    		scp -i $SSH_KEY imageArchive.tar $i:$CLIENT_IMAGE_DIR
done

wait  # for all archive to get copied


#make an array of all the servers that have launched.
count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	archiveArray[$count]=$i
	echo "Checking Array in creation:" ${archiveArray[$count]} "Count=$count"
	((count++))
done



#unarchive these on the clients (this should be part of above too)
count=0
for i in "${archiveArray[@]}"
do
		CURRENT_SERVER=${archiveArray[$count]} 
		echo "Server: $CURRENT_SERVER, Array Count $count"
		echoGood "Just about to unarchive the images on client: $i"
		ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "cd $JOB_LOCATION ; tar xf $JOB_LOCATION/imageArchive.tar &"
		((count++))
done
}


						siftListsPerServer () {

images=$NUMBER_OF_IMAGES
servers=$NUMBER_OF_SERVERS
	if [[ $servers -lt 1 ]] 
		then
			echo "You have no servers, exiting."
			exit 1
		else 
			echo "You have: $servers servers."
	fi
ips=$(( $images / $servers ))
remainder=$(( $images % $servers ))
echo Images Per Segment $ips Remainder: $remainder

count=1
	for ((i=1 ; i<=$servers; i++)) ; 
	do
		#echo "siftListsPerServer" loop number $i
			if [ "$remainder" -ge 1 ]
		then 
		# we still have a remainder
			add=1
		else 
		# we no longer have a remainder
			add=0
	fi	
		
	for ((j=1 ; j<= $(( $ips + $add )) ; j++))
		do #echo $i $j
			sed -n "$count"p $IMG_LOG_DIR/img_list.txt >> siftlists/"$i"_siftlist.txt
			((count++))
		done
	((remainder--))
	done
# Matching has load balancing since it takes longer... one day sifts will too.
}


								copyListsToServers () {


count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	copyListArray[$count]=$i
	((count++))
done

j=`ls -1 $HAVE_LAUNCHED_DIR | wc -l`
	for (( i=1; i <= $j ; i++ ))
		do
			serverItterator=$(( i - 1 ))
			CURRENT_SERVER=${archiveArray[$serverItterator]}  
			echo Server: $CURRENT_SERVER, Number: $i
			
			fping $CURRENT_SERVER
			if [[ "$?" -ne "0" ]] ; then
				echo "Client will be rm'd from busy/idle/have launched" 
				echo rm $BUSY_DIR/$CURRENT_SERVER $HAVE_LAUNCHED_DIR/$CURRENT_SERVER $IDLE_DIR/$CURRENT_SERVER
			else
				echoGood "Server exists!"
				echo scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$JOB_LOCATION 
				scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$JOB_LOCATION 
			fi			
		done
}

								 				  
					startSifts () {

count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	startSiftArray[$count]=$i
	((count++))
done

j=${#startSiftArray[@]} 
echo "The size of J is $j"
for (( i=1 ; i <= $j ; i++)) ; do
	siftArrayItterator=$(( i -1 ))
	CURRENT_SERVER=${startSiftArray[$siftArrayItterator]}
	echo "Creating SiftSH for Server $CURRENT_SERVER as count of $j"

	echo cd $JOB_LOCATION > $JOBS_SET/"$i"_sift_JOB.sh
	echo "echo \"Executing script\"" >>$JOBS_SET/"$i"_sift_JOB.sh
	echo VisualSFM siftgpu "$i"_siftlist.txt >> $JOBS_SET/"$i"_sift_JOB.sh
	echo scp -i $SSH_KEY -r *.sift $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR >> $JOBS_SET/"$i"_sift_JOB.sh

	chmod +x $JOBS_SET/"$i"_sift_JOB.sh

	scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$JOBS_SETUP

	IN_FILE="$i"_sift_JOB.sh 
	ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $JOBS_SETUP/\$RFILE $JOBS_PENDING/\$RFILE"

	mv $JOBS_SET/"$i"_sift_JOB.sh $JOBS_DONE/
done
}


								waitForSiftsToFinish () {

DIR_SIFTS=`ls -1 $SOURCE_IMAGE_DIR/*.sift 2>/dev/null | wc -l`
DIR_PEGS=`ls -1 $SOURCE_IMAGE_DIR/*.[jJ][pP][gG] | wc -l`
echo DIR_SIFTS= $DIR_SIFTS DIR_PEGS= $DIR_PEGS

while [ "$DIR_SIFTS" -lt "$DIR_PEGS" ]
do
#     printf "Still not enought sifts back. ."
#     sleep 1
#     printf "\rStill not enought sifts back. ."
    DIR_SIFTS=`ls -1 $SOURCE_IMAGE_DIR/*.sift 2>/dev/null | wc -l`

ProgressBar $DIR_SIFTS $DIR_PEGS

#     echo DIR_SIFTS = $DIR_SIFTS
done
echo "All sifts are returned."

}

								 getInverseSifts () {

#make an array of all the servers that have launched.
count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	inverseSiftsArray[$count]=$i
	echo "Checking Array in creation:" ${inverseSiftsArray[$count]} "(Count=)"$count
	((count++))
done

echo "========================="

count=0
j=${#inverseSiftsArray[@]}
echo "size of inverseSiftsArray is: $j"
for (( i=1 ; i <= $j ; i++)) ; do
	inverseSiftsItterator=$(( i - 1))
	CURRENT_SERVER=${inverseSiftsArray[$inverseSiftsItterator]}
	echo "Checking Current Server :" $CURRENT_SERVER "(Count=)"$inverseSiftsItterator

	#sould become function (getLoopCurrentServerID#
	cat <<EOF > $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh
			cd $CLIENT_WORKDIR
			echo MY PWD IS... $PWD
			MAIN=".sift"
			INVERT=".JPG"
			ls -1 *.sift > .main_list
			ls -1 *[jJ][pP][gG] > .invert_list
			echo "sed1"
			sed "s/.[jJ][pP][gG]//g" .invert_list > .invert_no_ext
			echo "sed2"
			sed "s/.sift//g" .main_list > .main_no_ext
			echo "sed3"
			sdiff .invert_no_ext .main_no_ext | grep "<" | sed 's/<//g'
			sdiff .invert_no_ext .main_no_ext | grep "<" | sed 's/<//g' > .outlist_prext.txt
			for i in \`cat .outlist_prext.txt\` 
				do 
					scp -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/\$i.sift . ;
					done
			rm .outlist_prext.txt
			ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "touch $SOURCE_IMAGE_DIR/got_sifts_$i"
EOF

	chmod +x $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh

	scp -i $SSH_KEY $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh $CURRENT_SERVER:$JOBS_SETUP

	IN_FILE="$i"_SIFT_MOVE_JOB.sh
	ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $JOBS_SETUP\$RFILE $JOBS_PENDING/\$RFILE"
	mv $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh $JOBS_DONE/"$i"_SIFT_MOVE_JOB.sh
done

}


								 waitForSiftsToCopy () {
NUMBER_OF_SERVERS=`ls -1 $HAVE_LAUNCHED_DIR | wc -l`
DOES_SIFT_EXIST=0

echo "Waiting for sifts to copy back to clients."

while [ "$DOES_SIFT_EXIST" -lt "$NUMBER_OF_SERVERS" ]
do 
#    echo "DOES_SIFT_EXIST = $DOES_SIFT_EXIST"
	DOES_SIFT_EXIST=`ls -1 $SOURCE_IMAGE_DIR/*got_sifts* 2>/dev/null | wc -l`
    ProgressBar $DOES_SIFT_EXIST $NUMBER_OF_SERVERS
#    sleep 1
done
echo "All Sifts at home exist"
}

									getMatchListTotal () {
### This needs a bit of work... creates a few incorrect matches, eg, just one match pair instead of two.

#iterate through each primary image
TOTALCOUNT=0

#not sure why I did this... nasty code.
OLD_IFS=$IFS
IFS=$'\r\n' GLOBIGNORE='*' :;
FILENAMEARRAY=($(cat $IMG_LOG_DIR/img_list.txt))

for (( c = 1; c <= $IMAGES; c++ ))
	do
	MATCHBEGIN=$(( c + 1 ))
	MATCHLOOP=$(( c + 1 ))

		#itterate through each image to match
		for (( $MATCHLOOP ; $MATCHLOOP<=$IMAGES; MATCHLOOP++ ))
			do 
			((TOTALCOUNT++))
			SECONDPAIR=${FILENAMEARRAY[$MATCHLOOP]}
			MAINPAIR=${FILENAMEARRAY[$c]}

				echo $MAINPAIR $SECONDPAIR >> $MATCH_LIST_DIR/.matchtmp.txt
	
		done
done
IFS=$OLD_IFS

echo TOTAL COUNT = $TOTALCOUNT
echo 
PER_SERVER=$(( TOTALCOUNT / NUMBER_OF_SERVERS ))
REMAINDER=$(( TOTALCOUNT % NUMBER_OF_SERVERS ))
echo "Number of Pix per server is " $PER_SERVER
echo "Remainder ="$REMAINDER

}



BenchmarkMatch (){


#make an array of our lunched servers for matching
count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	matchArray[$count]=$i
	((count++))
done

#get their matchbenchmark and put it in currentServerMatchBenchmark[]
serverCount=0
for i in "${matchArray[@]}" ; do
    #echo currentServerMatchBenchmark=`ssh -i $SSH_KEY $SFM_USERNAME@$i "cat $CLIENT_WORKDIR/matchSpeed"`   
    currentServerMatchBenchmark=`ssh -i $SSH_KEY $SFM_USERNAME@$i "cat $CLIENT_WORKDIR/matchSpeed"`   
    BENCHMARK_SERVER[$serverCount]=$currentServerMatchBenchmark
    ((serverCount++))
done

echo "Server Benchmarks are: ${BENCHMARK_SERVER[@]}"

#find fastest machine...

low=0
count=0
lowIndex=0

for i in "${BENCHMARK_SERVER[@]}"
do 
j=${BENCHMARK_SERVER[$count]}
echo "j = $j"   
        if [ "$low" -eq "0" ]
                then low=$j
                fi  

        if [ $j -lt $low ]
                then low=$j
                     lowIndex=$count
        fi  
((count++))
done
echo lowest is $low

#find their speed reciprocal by adding getting a total of the speeds and dividing by the fastest
count=0
sum=0
for i in "${BENCHMARK_SERVER[@]}"
	do
		j=${BENCHMARK_SERVER[$count]}
		echo "J is $j, count =$count"
		reciprocalArray[$count]=`echo "scale=5; $low / $j" | bc`
		echo "scale=5; $low / $j" | bc
		echo "ReciprocalArray $count = " ${reciprocalArray[$count]}
		sum=`echo "scale=5;  ${reciprocalArray[$count]} + $sum" | bc`
((count++))
done

#work out the total reciprocal
echo "sum =$sum"
totalReciprocalFactor=`echo "scale=5 ; 1 / $sum " | bc`
echo $totalReciprocalFactor



NUMBER_OF_SERVERS_BENCHMARK=${#BENCHMARK_SERVER[@]}
echo "Number of servers benchmarked" $NUMBER_OF_SERVERS_BENCHMARK
MATCH_TOTAL=0
MATCH_LIST=$MATCH_LIST_DIR/.matchtmp.txt
MATCH_LIST_TOTAL=`wc -l $MATCH_LIST | awk '{ print $1 }'`
END_LIST=$((MATCH_LIST_TOTAL - 1))


#create an array of those factored speeds
count=0
totalImages=$MATCH_LIST_TOTAL
for i in "${BENCHMARK_SERVER[@]}"
	do
		j=${benchArray[$count]}
		benchArrayFactored[$count]=`echo "scale=5 ; ${reciprocalArray[$count]} * $totalReciprocalFactor " | bc`
		benchImagesFactored[$count]=`echo "scale=5 ; $totalImages * ${benchArrayFactored[$count]}" | bc`
		echo Original : $j Adjusted : ${benchArrayFactored[$count]} : perCluster ${benchImagesFactored[$count]} 
((count++))
done




for (( i=0; i < $NUMBER_OF_SERVERS_BENCHMARK ; i++ ))
	do
		k=${BENCHMARK_SERVER[$i]}
		((MATCH_TOTAL=MATCH_TOTAL + k ));
done

START_LINE=1

for (( i=0; i < $NUMBER_OF_SERVERS_BENCHMARK ; i++))
do
        CURRENT_BENCHMARK=${BENCHMARK_SERVER[$i]}
	   num=${benchImagesFactored[$i]}
        num=${num%.*} #convert to dirty int rounding...

        MATCH_CUT=$num       


		MATCH_INC=${MATCH_CUT%.*}
		END_ARRAY_NUM=$(( NUMBER_OF_SERVERS_BENCHMARK ))
		FILENAME=matchlist_$((i +1)).txt
		echo FILENAME IS $FILENAME
			INC_I=$((i +1 ))
		echo i=$i INC_I=$INC_I END_ARRAY_NUM=$END_ARRAY_NUM

	if [[ INC_I -ne END_ARRAY_NUM ]]
	then
		echo LIST $FILENAME
		END_LINE=$((START_LINE + MATCH_INC))
		echo START $START_LINE END $END_LINE
		echo "DEBUGMain1"
		echo START_AND_END_"$START_LINE","$END_LINE"
		sed -n "$START_LINE","$END_LINE"p $MATCH_LIST_DIR/.matchtmp.txt  > $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt
		echo "DEBUGMainEnd"
		START_LINE=$(( END_LINE + 1 ))
	else	
		#echo $FILENAME
		echo START_LINE: $START_LINE MATCH_LIST_TOTAL $MATCH_LIST_TOTAL
        	echo "DEBUG_EndLoop"
		echo START_AND_LASTLOOP_"$MATCH_LIST_TOTAL"
		sed -n "$START_LINE","$MATCH_LIST_TOTAL"p $MATCH_LIST_DIR/.matchtmp.txt > $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt
		echo "DEBUG_EndLoop"
		fi
echo "CS"

#read nothing

#CURRENT_SERVER=`sed -n "$INC_I"p $SERVERS_CLIENT_LIST`
echo "matchArray i = ${matchArray[$i]} "
CURRENT_SERVER=${matchArray[$i]}
#CURRENT_SERVER=`sed -n "$INC_I"p $SERVERS_CLIENT_LIST`


echo "CS_END" 
echo scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_IMAGE_DIR
scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_IMAGE_DIR

done

}
		

									makeMatchLists () {
getMatchListTotal


count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	makeMatchListsArray[$count]=$i
	((count++))
done


# make the lists for each server
#for (( c=1; c<=$NUMBER_OF_SERVERS; c++ ))

for (( c=0; c<=$NUMBER_OF_SERVERS; c++ ))
	do
	echo "$c ****************************"
	STARTLINE=$(( c * PER_SERVER - PER_SERVER + 1))

	if [ "$c" -eq $NUMBER_OF_SERVERS ]
	then 
		echo "I'm on the last loop!!!"
		ENDLINE=$(( c * PER_SERVER + REMAINDER ))
                echo $STARTLINE $ENDLINE
                sed -n "$STARTLINE","$ENDLINE"p $MATCH_LIST_DIR/.matchtmp.txt  > $SOURCE_IMAGE_DIR/matchlist_$c.txt
	else
		ENDLINE=$(( c * PER_SERVER ))
        	echo $STARTLINE $ENDLINE
        	sed -n "$STARTLINE","$ENDLINE"p $MATCH_LIST_DIR/.matchtmp.txt  > $SOURCE_IMAGE_DIR/matchlist_$c.txt 
	fi
	
currentServer=$(( c - 1 ))
CURRENT_SERVER=${makeMatchLists[$currentServer]}


echo "I think we fail here?"
echo scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$c.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_IMAGE_DIR
scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$c.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_IMAGE_DIR
echo "I think we fail here?^^^^^"
done                     
}
														
								 #~ ███       ██   ▓██▓ 
								   #~ █      ▒██  ▒█  █▒
								   #~ █      █░█  █░  ▒█
								   #~ █     ▓▓ █  █    █
								   #~ █    ░█  █  █  █ █
								   #~ █    █▒  █  █    █
								   #~ █    ██████ █░  ▒█
								   #~ █        █  ▒█  █▒
								 #~ █████      █   ▓██▓ 
							
								startMatchesOnServers () {


count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	startMatchesOnServers[$count]=$i
	((count++))
done



#j=`wc -l $SERVERS_CLIENT_LIST | awk '{ print $1 }'`
j=`ls -1 $HAVE_LAUNCHED_DIR | wc -l`
for (( i=1 ; i <= $j ; i++ )) ; do 
	serverItterator=$(( i - 1 ))
	CURRENT_SERVER=${archiveArray[$serverItterator]}
	#CURRENT_SERVER=`sed -n "$i"p $SERVERS_CLIENT_LIST`

	cat <<EOF > $JOBS_SET/"$i"_MATCH_JOB.sh
	cd $CLIENT_IMAGE_DIR
	echo "About to match from list"
	VisualSFM sfm+pairs+skipsfm . nomatch.nvm matchlist_$i.txt

	VisualSFM sfm+skipsfm+exportp . matches_out_$i.txt
	scp -i $SSH_KEY matches_out_$i.txt $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/
	#cp matches_out_$i.txt $SOURCE_IMAGE_DIR/
EOF

	chmod +x $JOBS_SET/"$i"_MATCH_JOB.sh
	#mv $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_MATCH_JOB.sh $HOME/RENDER_SERVER/JOBS_PENDING/
	scp -i $SSH_KEY $JOBS_SET/"$i"_MATCH_JOB.sh $CURRENT_SERVER:$JOBS_SETUP
	IN_FILE="$i"_MATCH_JOB.sh
	ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $JOBS_SETUP\$RFILE $JOBS_PENDING/\$RFILE"

done
}
							
							

								waitForMatchesToExport () {
DOES_MAT_EXIST=0
while [ "$DOES_MAT_EXIST" -lt "$NUMBER_OF_SERVERS" ]
do 
  echo "Waiting for Matches to copy..."
  echo "DOES_MAT_EXIST = $DOES_MAT_EXIST"
  DOES_MAT_EXIST=`ls -1 $SOURCE_IMAGE_DIR/matches_out* 2>/dev/null | wc -l`
    sleep 1
  done
  echo "All Match Exports at home exist"
}


								 #~ ███     ▒███▒  ▓██▓ 
								   #~ █    ░█▒  ▓ ▒█  █▒
								   #~ █    █▒     █░  ▒█
								   #~ █    █▒███  █    █
								   #~ █    █▓  ▓█ █  █ █
								   #~ █    █    █ █    █
								   #~ █    █    █ █░  ▒█
								   #~ █    ▒▓  ▓█ ▒█  █▒
								 #~ █████   ▓███   ▓██▓ 
combineMatch () {

for i in `ls -1 $SOURCE_IMAGE_DIR/matches_out*` ; do
	echo $i
	sed "s/.*\///" $i > `basename $i .txt`_local_path.txt
	VisualSFM sfm+skip+import+skipsfm . out.nvm `basename $i .txt`_local_path.txt
done
#VisualSFM sfm+exportp [input] matches.txt
#VisualSFM sfm+skip+import+skipsfm [full_image_list] [output.nvm] matches1.txt
#VisualSFM sfm+skip+import+skipsfm [full_image_list] [output.nvm] matchesn.txt

}
								 #~ ███    ██████  ▓██▓ 
								   #~ █        ▓▓ ▒█  █▒
								   #~ █        █  █░  ▒█
								   #~ █       ▒█  █    █
								   #~ █       █░  █  █ █
								   #~ █      ▒█   █    █
								   #~ █      █░   █░  ▒█
								   #~ █     ▒█    ▒█  █▒
								 #~ █████   █▒     ▓██▓ 



function copyMatchesToRealServers () {

count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	copyMatchesToServers[$count]=$i
	((count++))
done


#for i in `cat $SERVERS_CLIENT_LIST`

for i in "${copyMatchesToServers[@]}"
do 
scp -i $SSH_KEY *.mat $i:$CLIENT_WORKDIR/task_processing
#     for j in `ls -1 $SOURCE_IMAGE_DIR/*.mat`
#	do
#	scp -i dloud.pem $j $i:/media/ephemeral
#	done
done
}




								  #~ ███    ░████░  ▓██▓ 
								   #~ █    █▒  ▒█ ▒█  █▒
								   #~ █    █    █ █░  ▒█
								   #~ █    █▒  ▒█ █    █
								   #~ █     ████  █  █ █
								   #~ █    █▒  ▓█ █    █
								   #~ █    █    █ █░  ▒█
								   #~ █    █▓  ▒█ ▒█  █▒
								 #~ █████  ░████░  ▓██▓ 


startLocalSFM ()
{

cd $SOURCE_IMAGE_DIR
time VisualSFM sfm+nomatch+cmvs . $PROJECT_NAME
# this ideally would leave us with 00/bundlerd.out for each dir, this is not the case as yet... or we need an nvm>bundler solution
cd -
echo "Done SFM"
}

copyCMVSDirToServers () {

#
count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	copyCMVSDirToServers[$count]=$i
	((count++))
done


echo "Tarring CMVS dirs"
echo "I am in directory..."  $PWD  "-- end PWD"

echo $CMVS_NAME


tar cf cmvs.tar $CMVS_NAME


count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
	copyCMVSDirToServers[$count]=$i
	scp -i $SSH_KEY cmvs.tar $i:$CLIENT_IMAGE_DIR &
	((count++))
done
wait

# for i in `cat $SERVERS_CLIENT_LIST`
# do 
# 		scp -i $SSH_KEY cmvs.tar $i:$CLIENT_IMAGE_DIR &
# 	done
# wait

count=0
for i in `ls -1 $HAVE_LAUNCHED_DIR` ; do 
#for i in `cat $SERVERS_CLIENT_LIST`
#do
			CURRENT_SERVER=${copyCMVSDirToServers[$count]}
			#CURRENT_SERVER=`sed -n "$count"p $SERVERS_CLIENT_LIST` 
			echo server $CURRENT_SERVER number $i

			#scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$CLIENT_IMAGE_DIR

			ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "cd $CLIENT_IMAGE_DIR ; tar xf $CLIENT_IMAGE_DIR/cmvs.tar &"
			((count++))
done

}

determinePMVS_JOBS () {
echo "in function determinePMVS_JOBS"
pmvsCount=0 
for i in `ls -1 $CMVS_NAME` 
	do 
	PMVS_DIR[$pmvsCount]="$i"
	echo "PMVS_DIR #$count ="${PMVS_DIR[$pmvsCount]}
	((pmvsCount++))
done

}

preparePMVS_Jobs () {
pmvsJobCount=0

# loop through each 00/ 01/ ... as from array contents
for i in "${PMVS_DIR[@]}"
	do
  	# this is weird, both are the same so don't need to display!
  	echo "key  : $i"
  	echo "value: ${PMVS_DIR[$i]}"
	#get a value for the directory name eg, yoursfm.nvm.cmvs/00... 
	currentCMVSDIR=$CMVS_NAME/$(printf %02d ${PMVS_DIR[$i]})
	echo "CD is $currentCMVSDIR"
		
		#now we go through each 00/ and 01 etc and make a job script
		for j in `ls -1 $currentCMVSDIR/option*` ; do 
			 #this variable is for assigning a job name
                 	padJobNumber=$(printf %04d $pmvsJobCount)
			jobNamePrefix=${j##*/}
			currentClusterOptionPLY="pmvs_job_"$i"_"$jobNamePrefix"_"$padJobNumber".sh"
			echo "Filename for Job is: $currentClusterOptionPLY"
			echo "CMVS NAME is.... $CMVS_NAME"
#generate pmvs job script
cat <<EOF > $JOBS_SET/$currentClusterOptionPLY
#!/bin/bash
cd $CLIENT_IMAGE_DIR/$CMVS_NAME
CPU_NUMBER=\$(cat $RENDER_SERVER/maxThreads)
sed -i_CPU "s/CPU.*/CPU \$CPU_NUMBER/g" $i/${j##*/}
pmvs2 $i/ ${j##*/}
echo "about to copy scp -i $SSH_KEY $i/models/${j##*/}.ply $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/$CMVS_NAME/$i/models/"
scp -i $SSH_KEY $i/models/${j##*/}.ply $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/$CMVS_NAME/$i/models/
EOF
			chmod +x $JOBS_SET/$currentClusterOptionPLY
			((pmvsJobCount++))
			echo ""
			echo "***********************"
			echo ""
		done
		

#       scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$JOBS_SETUP
#       IN_FILE="$i"_sift_JOB.sh
#       ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE 
#       mv $JOBS_SETUP\$RFILE $JOBS_PENDING/\$RFILE"
#       mv $JOBS_SET/"$i"_sift_JOB.sh $JOBS_DONE/
	


	

	echo "End of enterPMVS_Dirs Loop $i"
	done

}


startPMVS_Sender () {
echo "in Function PMVS Sender"
# jobs from launch script need to send out 

while true
 do
	printf "Distributing PMVS Jobs...\n"
	pmvsJobsToDo=`ls -1 $JOBS_SET/pmvs_job* | wc -l`
	echo "pmvsJobsToDo = $pmvsJobsToDo"
		while [ "$pmvsJobsToDo" -gt 0 ]
		do
			printf "attempting to find a server available for pmvs job\n"
			firstMachineOnTheRank=`ls -1 $IDLE_DIR | head -1`
				if [ -z "$firstMachineOnTheRank" ] 
					then
						echo "Sorry, no machine available, please wait"
					else
						echo "Job will be sent out to $firstMachineOnTheRank"
						pmvsJobChoice=`ls -1 $JOBS_SET/pmvs_job* | head -1`
						if [[ -z "$pmvsJobChoice" ]] 
						then
							echo "All PMVS Jobs Done=]"
							exit 0
						else
							echo "Choosing $pmvsJobChoice to send to $firstMachineOnTheRank"
							scp -i $SSH_KEY $pmvsJobChoice $SFM_USERNAME@$firstMachineOnTheRank:$JOBS_PENDING/
							mv $pmvsJobChoice $JOBS_COMPLETE/
						fi
				fi
		sleep 1
		done
 sleep 1
done
	 	


#while jobs gt 0; 
#do 
#
#CURRENT_PMVS_JOB_TO_SEND=` ls -1 PMVS_JOBS | head -1` 
#if 
#CURRENT_FREE_HOST=`ls -1 $IDLE_DIR`
#fi
#
#done
:
}


startCMVS () {
:
#                           images/X       maxCPU  
cmvs $PROJECTNAME.nvm.cmvs/ maximage[=100] CPU[=16]

}

startPMVS () {

for i in servers; do cp $PROJECTNAME.nvm.cmvs/$k >> next server ; done
}


disconnectAllServers () {
#not yet imp
				###removed this varible so won't work...
for j in `ls -1 $IP_LOG_DIR`
do
waitForMatchesToExport
	echo "About to disconnect servers"
	#removing SERVER_IP....
	if [ "$SERVER_IP" == "$MASTERSERVER" ]
		then
			echo "Not disconnecting host!";
		else
			echo "Disconnecting " $j;
			ec2-terminate-instances `cat $j`;
	fi
done
}

getCMVSName() {
#the point of this stoping calling the cmvs dir images from gsearch...
echo "Getting CMVS Dir Name"
CMVS_DIR=$(find . -iname "*cmvs" | sed 's/.\///g')

NVM_NAME_DIR=${PWD##*/}
# echo "NVM_NAME_DIR ="$NVM_NAME_DIR
# BAD_NVM_NAME="images"
# if [[ $NVM_NAME_DIR == $BAD_NVM_NAME ]]
# 	then
# 		TMP=$(pwd | sed 's/\/images//')
# 		NVM_NAME_DIR=${TMP##*/}
# 		NVM_NAME=${NVM_NAME_DIR}.nvm
# 		#CMVS_PATH=images/
# 		
# 		
# 	else
# 			
# 		NVM_NAME=${NVM_NAME_DIR}.nvm
# fi
# echo NVM_NAME=$NVM_NAME
}

reconstructSFM () {
getCMVSName
echo VisualSFM sfm+nomatch+cmvs . $NVM_NAME_DIR
echo "done sparce reconstruction"
}

beginCMVSdistribution () {
### new personal standard is to call the vsfm project by the parent directory... otherwise this is why this mess is here...
getCMVSName
#CMVSDIR=$NVM_NAME.cmvs
OLD_IFS=$IFS
INS=$'\r\n' GLOBIGNORE='*' :;

	cd $CMVS_DIR
	MODEL_NAME_ARRAY=($(ls -1 | grep [0-9]))
	for i in "${MODEL_NAME_ARRAY[@]}" ; 
		do
	   		echo "${MODEL_NAME_ARRAY[$i]}"
	   		#OPTION_ARRAY=($(ls -1 ${MODEL_ARRAY[$i]}/option*))   		
		   	#cd "${MODEL_NAME_ARRAY[$i]}"
		   	ls -1 ${MODEL_NAME_ARRAY[$i]}/option* 		
 			
 			#### pmvs Render server begins here...
 			
 			
	    done	  

IFS=$OLD_IFS

}


# COMMON FUNCTIONS
     #~                              ▗▀              ▗   ▝              
	#~  ▄▖  ▄▖ ▗▄▄ ▗▄▄  ▄▖ ▗▗▖     ▗▟▄ ▗ ▗ ▗▗▖  ▄▖ ▗▟▄ ▗▄   ▄▖ ▗▗▖  ▄▖ 
	#~ ▐▘▝ ▐▘▜ ▐▐▐ ▐▐▐ ▐▘▜ ▐▘▐      ▐  ▐ ▐ ▐▘▐ ▐▘▝  ▐   ▐  ▐▘▜ ▐▘▐ ▐ ▝ 
	#~ ▐   ▐  ▐ ▐▐▐ ▐▐▐ ▐ ▐ ▐ ▐      ▐  ▐ ▐ ▐ ▐ ▐    ▐   ▐  ▐ ▐ ▐ ▐  ▀▚ 
	#~ ▝▙▞ ▝▙▛ ▐▐▐ ▐▐▐ ▝▙▛ ▐ ▐      ▐  ▝▄▜ ▐ ▐ ▝▙▞  ▝▄ ▗▟▄ ▝▙▛ ▐ ▐ ▝▄▞ 

#~ 
#~ copyBackGlob () {
	#~ scp 'SERVERNAME:/DIR/\*' .
#~ }


clearTempDirs () {

echo "Clearing All remote store Directories"
for i in `cat $SERVERS_CLIENT_LIST` ;
	do 
		echo "About to clear out client render dirs, hit ENTER or CTRL-C to cancel"
		read nothing		
		ssh -i $SSH_KEY $SFM_USERNAME@$i "rm -vr $CLIENT_LIST_DIR/*"
done

}


clearAllJobs () {

echo "About to clean render directories"
for i in `cat $SERVERS_CLIENT_LIST` ; do 
		:
		echo "not doing anything but learning from this!"
        #Farrkin insane!i!
        #why do we need to even do this?¿
        #ssh -i $SSH_KEY $SFM_USERNAME@$i "cd $JOBS_PENDING && rm -v *.sh ;  cd $JOBS_COMPLETE && rm -v *.sh " 
done
}


#### this is how it's meant to be done!!! oh well..
# j=`wc -l $SERVERS_CLIENT_LIST | awk '{ print $1 }'`
# 
# 	for (( i=1 ; i <= $j ; i++)) ; do
# 		CURRENT_SERVER=`sed -n "$i"p $SERVERS_CLIENT_LIST`
# 		echo "Creating SiftSH for $CURRENT_SERVER"
# 		
# 		##### WHERE YO AT YO
# 		#echo cd "$HOME"/.aws/servers/fake_servers/"$CURRENT_SERVER"/ 	 > $JOBS_SET/"$i"_JOB.sh
# 		#echo "echo your pwd is: \$PWD" 									>> $JOBS_SET/"$i"_JOB.sh
# 		echo cd $CLIENT_WORKDIR > $JOBS_SET/"$i"_sift_JOB.sh
# 		echo VisualSFM siftgpu "$i"_siftlist.txt >> $JOBS_SET/"$i"_sift_JOB.sh
# #		echo scpHome *.sift $SOURCE_IMAGE_DIR 	 >> $JOBS_SET/"$i"_sift_JOB.sh
# 		echo scp -i $SSH_KEY -r *.sift $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR >> $JOBS_SET/"$i"_sift_JOB.sh
# 
# 	
# 		chmod +x $JOBS_SET/"$i"_sift_JOB.sh
# 		
# 		scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$JOBS_SETUP
# 
# 		IN_FILE="$i"_sift_JOB.sh 
# 		ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $JOBS_SETUP\$RFILE $JOBS_PENDING/\$RFILE"
# 
# #		scpToCueIp "$i"_JOB.sh $CURRENT_SERVER
# 		
# 		mv $JOBS_SET/"$i"_sift_JOB.sh $JOBS_DONE/
# 	done







scpTo () {
	echo "in function scpTO!"
	SCP_FILE=$1
	DEST_IP=$2
	SCP_REMOTE_DIR=$3
	scp -i $SSH_KEY -r $SCP_FILE $SFM_USERNAME@$DEST_IP:$SCP_DIR
}

scpToCueIp () {
	echo "in function scpToCueIp"
	IN_FILE=$1
	DEST_IP=$2
	ssh -i $SSH_KEY $SFM_USERNAME@$DEST_IP "RFILE=$IN_FILE ; mv ~/RENDER_SERVER/JOBS_SETUP/\$RFILE ~/RENDER_SERVER/JOBS_PENDING/\$RFILE"

	# ssh -i ~/dsw/aws/dloud.pem $SFM_USERNAME@107.23.25.221 "RFILE=$FILE ; mv ~/RENDER_SERVER/JOBS_SETUP/\$RFILE ~/RENDER_SERVER/JOBS_PENDING/\$RFILE"
}	

scpHome () {
	echo "in function scpHome!"
	IN_FILE=$1
	DEST_IP=$HOME_IP
	scp -i $SSH_KEY -r $SCP_FILE $SFM_USERNAME@$DEST_IP:$SOURCE_IMAGE_DIR
	:
}

writeIPInstanceID () {

CURRENT_INSTANCE_IP=$1
CURRENT_INSTANCE_LOG=$2
#first make a file with the ip address name
touch `cat $IPLOGDIR/$CURRENT_INSTANCE_LOG | grep PRIVATEIPADDRESS | awk '{print $2}'` 
#then echo that into the file
cat $IPLOGDIR/$CURRENT_INSTANCE_LOG | grep INSTANCE | awk '{print $2}' > $IPLOGDIR/$CURRENT_INSTANCE_IP

}


testCommandLocal () {
echo " Check, check...  good check."
}

#~ archiveImages () {
#~ tar xf $SOURCE_IMAGE_DIR.tar *.JPG
#~ IMAGE_BUNDLE=$SOURCE_IMAGE_DIR.tar
#~ echo "IMAGE_BUNDLE = $IMAGE_BUNDLE"
#~ }
# echo "		             ▄▄▖             ▄▄           ▗▄▖    █  ▗▖   "
# echo "		            ▐▀▀█▖           ▐▛▀           ▝▜▌    ▀  ▐▌   "
# echo "		   ▟█▙  ▟██▖   ▐▌     ▗▟██▖▐███ ▐█▙█▖      ▐▌   ██  ▐▙█▙ "
# echo "		  ▐▙▄▟▌▐▛  ▘  ▗▛      ▐▙▄▖▘ ▐▌  ▐▌█▐▌      ▐▌    █  ▐▛ ▜▌"
# echo "		  ▐▛▀▀▘▐▌    ▗▛        ▀▀█▖ ▐▌  ▐▌█▐▌      ▐▌    █  ▐▌ ▐▌"
# echo "		  ▝█▄▄▌▝█▄▄▌▗█▄▄▖     ▐▄▄▟▌ ▐▌  ▐▌█▐▌  █   ▐▙▄ ▗▄█▄▖▐█▄█▘"
# echo "		   ▝▀▀  ▝▀▀ ▝▀▀▀▘      ▀▀▀  ▝▘  ▝▘▀▝▘  ▀    ▀▀ ▝▀▀▀▘▝▘▀▘ "

