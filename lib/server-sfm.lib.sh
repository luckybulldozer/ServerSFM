#!/bin/bash
# server-sfm.lib

LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
echo "Installer says libdir= $LIBDIR"
source $LIBDIR/dsCommon.lib.sh

echo "                                     _____ ________  ___   "
echo "     ________  ______   _____  _____/ ___// ____/  |/  /   "
echo "    / ___/ _ \/ ___/ | / / _ \/ ___/\__ \/ /_  / /|_/ /    "
echo "   (__  )  __/ /   | |/ /  __/ /   ___/ / __/ / /  / /     "
echo "  /____/\___/_/    |___/\___/_/   /____/_/   /_/  /_/  0.1.0"
echo ""
echo "Booting SFM..."


initVars () {

#SFM_INSTALL_DIR=$(readPrefs sfmDir)"/somthing/"

#alter these three variables for your own configuration

#main ssh key that connects host to clients and vice versa
SSH_KEY=$(readPrefs sshKey)
SSH_KEY_C=$(readPrefs sshKey)

#this is the username on ALL machines... will need to work out a new way to work under different names...
SFM_USERNAME=$(readPrefs username);


SSFM_INSTALL_DIR=$(readPrefs ssfmInstallDir)
echo "trying to assign SSFM_INSTALL_DIR to $SSFM_INSTALL_DIR"

SERVER_WORKDIR=$(readPrefs serverWorkDir)

echo "trying to assing SERVER_WORKDIR to $SERVER_WORKDIR"
#where img_list.txt and matches/.matchtmp.txt is kept
IMG_LOG_DIR=$(readPrefs serverWorkDir)"/imglogdir"

#where serverlist.txt a list of used servers is kept
# this is wrong!!!



#where .matchtmp.txt is kept
MATCH_LIST_DIR=$IMG_LOG_DIR/matches

#Location of Jobs Cues on Clients
JOBS_SET=$(readPrefs serverWorkDir)"/jobs/server/set"
JOBS_DONE=$(readPrefs serverWorkDir)"/jobs/server/done"

#Host Idle Directory
IDLE_DIR=$(readPrefs serverWorkDir)"/jobs/server/hosts/idle"

#where the server lists clients                                  ## set to idle eventually
SERVER_CLIENTS_LIST_DIR=$(readPrefs serverWorkDir)"/server/clients/have_launched"
SERVERS_CLIENT_LIST=$SERVER_WORKDIR"/jobs/server/clients/clientlist.txt"

#Directory on Clients where the images are worked on.
CLIENT_WORKDIR=$(readPrefs clientWorkDir)


## RUNTIME VARIABLES (not part of preferences)

# This is the main machine the script is executed on.
MASTER_SERVER=$(hostname).local

#directory where script is executed (should only contain images!)
#!#change to IMAGE_DIR
SOURCE_IMAGE_DIR=$PWD

#vsfm project name
#!#change to ${IMAGE_DIR}.nvm
PROJECT_NAME=${SOURCE_IMG_DIR##*/}.nvm

#cmvs directory
CMVS_NAME=$PROJECT_NAME.cmvs

TEST_PREF=$(readPrefs testPref)
}

displayPrefs() {
echo "Displaying User Variables from prefs"
echo "SFM_USERNAME : $SFM_USERNAME"
echo "SSFM_INSTALL_DIR: $SSFM_INSTALL_DIR"
echo "IMG_LOG_DIR: $IMG_LOG_DIR"
echo "CLIENT_LIST_DIR: $CLIENT_LIST_DIR"
echo "SERVER_WORKDIR: $SERVER_WORKDIR"
echo "CLIENT_WORKDIR: $CLIENT_WORKDIR"
echo "TEST_PREF: $TEST_PREF"
echo "JOBS_DONE: $JOBS_DONE"
echo "JOBS_SET: $JOBS_DONE"
}


initVars_sh_server () {

#this should just be part of the above... as the host is also a client of itself, plus not sure it just gets executed by the host anyway!

RENDER_SERVER=$SERVER_WORKDIR/jobs/client/
#RENDER_SERVER=$SFM_INSTALL_DIR/

#RENDER_SERVER="$HOME/sfm/RENDER_SERVER"
#JOBS_PENDING=$RENDER_SERVER/JOBS_PENDING/
JOBS_PENDING=$RENDER_SERVER/pending/
}

initRm () {
# should build in yell, plus page this out to more.
echo ""
echo "About to rm all the stuff in $SOURCE_IMAGE_DIR execept the JPGS of course... hit ENTER or CTRL-C to fail"

rm -fr $IMG_LOG_DIR/match* $IMG_LOG_DIR/left_pair $IMG_LOG_DIR/right_pair $IMG_LOG_DIR/*clean_pair* $CLIENT_LIST_DIR $SOURCE_IMAGE_DIR/*sift* $SOURCE_IMAGE_DIR/match* $MATCH_LIST_DIR/.matchtmp.txt $SOURCE_IMAGE_DIR/got_sifts $SOURCE_IMAGE_DIR/*.mat $SOURCE_IMAGE_DIR/match* $SOURCE_IMAGE_DIR/*nvm* $SOURCE_IMAGE_DIR/siftlists $IDLE_DIR/*

echo "Contents now in $SOURCE_IMAGE_DIR/"
ls $SOURCE_IMAGE_DIR
echo "Hit ENTER again to continue..."
read nothing_again

}

initDirs () {
#replaced by just copying our main dir?
mkdir -pv $SERVER_WORKDIR/iplog $SERVER_WORKDIR/imglogdir/matches $SOURCE_IMAGE_DIR/siftlists 
:
}

#not sure about this...
initClientDirs () {
mkdir -pv $CLIENT_WORKDIR"/iplog" $CLIENT_WORKDIR"/imglogdir/matches" $CLIENT_IMAGE_DIR"/siftlists"
mkdir -pv $CLIENT_WORKDIR"/serverID/"
}




getImgList () {
									
ls -1 *.[jJ][Pp][Gg] > $IMG_LOG_DIR/img_list.txt
IMAGES=`wc -l $IMG_LOG_DIR/img_list.txt | awk '{print$1}'`
NUMBER_OF_IMAGES=$IMAGES
echo $IMAGES
}


assignClientRange () {
# this needs to read from our list @ $SERVER_WORKDIR/jobs/server/clients/clientlist.txt

#rm -fr $CLIENT_LIST_DIR/serverlist.txt
echo "Server List is: `cat $SERVER_WORKDIR/jobs/server/clients/clientlist.txt`"
NUMBER_OF_SERVERS=$(wc -l $SERVER_WORKDIR/jobs/server/clients/clientlist.txt | awk {'print $1'})

}
				 				  


clientInit () {

SERV_PLAN=`cat $SERVER_WORKDIR/jobs/server/clients/clientlist.txt | wc -l`
SERV_ONLINE=`ls -1 $SERVER_CLIENTS_LIST_DIR | wc -l`
echo SERV_PLAN= $SERV_PLAN SERV_ONLINE= $SERV_ONLINE

while [ "$SERV_ONLINE" -lt "$SERV_PLAN" ]
	do
	    echo "Still not enought Servers launched..."
	    sleep 1
	    SERV_ONLINE=`ls -1 ~/sfm/online_servers 2>/dev/null | wc -l`
	    echo SERV_ONLINE = $SERV_ONLINE
done

echo "looks like all Servers are Online!"

}



##                                 ###   ##
##                               ## ##   ##
##                             ##   ##   ##
##                                  ##   ##
##                                  ##   ##
                           initRemoteServers () {


echo "LS'n servers:"
for i in `cat $SERVERS_CLIENT_LIST` ;do 
# this line removes the ip from knownhosts to prevent a Spoof Login
    ssh-keygen -F "~/.ssh/known_hosts" -R $i
#	ping -c 1 $i
#	scp -i $SSH_KEY ~/sfm/server_sfm/launch_sh_server.sh $SFM_USERNAME@$i:~/sfm/server_sfm/
#	scp -i $SSH_KEY ~/sfm/server_sfm/sh_server.sh $SFM_USERNAME@$i:~/sfm/server_sfm/
#	scp -i $SSH_KEY ~//sfm/server_sfm/server_sfm-sfm.lib $SFM_USERNAME@$i:~/sfm/server_sfm/
# copy yrself yo!

	scp -i $SSH_KEY $SSFM_INSTALL_DIR $SFM_USERNAME@i:$CLIENT_WORKDIR/
#	ssh -i $SSH_KEY $SFM_USERNAME@$i "mkdir -p ~/JOBS/SET"
#	ssh -i $SSH_KEY $SFM_USERNAME@$i "mkdir -p ~/JOBS/SET"
# 	ssh -i $SSH_KEY $SFM_USERNAME@$i "mkdir -p ~/JOBS/DONE"
# 	ssh -i $SSH_KEY $SFM_USERNAME@$i "mkdir -p $CLIENT_WORKDIR"
done

}

#scp -i ~/dloud.pem -r $1 $SFM_USERNAME@10.0.0.164:~/
#40r








fakeServerCreation () {
# works...  
mkdir -p $CLIENT_LIST_DIR/fake_servers

for i in `cat $CLIENT_LIST_DIR/serverlist.txt` ; do
mkdir -p $CLIENT_LIST_DIR/fake_servers/$i

done

echo "LS'n $CLIENT_LIST_DIR/fake_servers:"
ls $CLIENT_LIST_DIR/fake_servers
}

								 #~ █████   ▓██▓ 
								 #~ █      ▒█  █▒
								 #~ █      █░  ▒█
								 #~ ████▒  █    █
								    #~ ░█▓ █  █ █
								      #~ █ █    █
								      #~ █ █░  ▒█
								 #~ █░  █▓ ▒█  █▒
								 #~ ▒███▓   ▓██▓ 

								 copyImagesToRealServers () {

echo in CopyImagesToRealServers

echo "Tarrring"
tar cf imageArchive.tar --directory=$SOURCE_IMAGE_DIR/ *.[jJ][pP][gG]

for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do 
    #for j in `cat $IMG_LOG_DIR/img_list.txt` ;do	
    ssh-keygen -F "~/.ssh/known_hosts" -R $i 1>&2
		scp -i $SSH_KEY imageArchive.tar $i:$CLIENT_WORKDIR &
		#scp -i $SSH_KEY $j $i:$CLIENT_WORKDIR
	#done
done
wait

count=1
for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do
		
			CURRENT_SERVER=`sed -n "$count"p $CLIENT_LIST_DIR/serverlist.txt` 
			echo server $CURRENT_SERVER number $i

			#scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$CLIENT_WORKDIR

			ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "cd $CLIENT_WORKDIR ; tar xf $CLIENT_WORKDIR/imageArchive.tar &"
			((count++))
done
}




#50-r
copyImagesToFakeServers () {
for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do 
     for j in `cat $IMG_LOG_DIR/img_list.txt`
	do
	
	cp -v $j $CLIENT_LIST_DIR/fake_servers/$i

# this works... but it makes the sifts back in the original locaiton!!!
#     	ln -s $SOURCE_IMAGE_DIR/$j $CLIENT_LIST_DIR/fake_servers/$i/$j

	done
done
}

								              #~ 
								  #~ ▒███▒  ▓██▓ 
								 #~ ░█▒  ▓ ▒█  █▒
								 #~ █▒     █░  ▒█
								 #~ █▒███  █    █
								 #~ █▓  ▓█ █  █ █
								 #~ █    █ █    █
								 #~ █    █ █░  ▒█
								 #~ ▒▓  ▓█ ▒█  █▒
								  #~ ▓███   ▓██▓ 

								siftListsPerServer () {


images=$NUMBER_OF_IMAGES
servers=$NUMBER_OF_SERVERS
ips=$(( $images / $servers ))
remainder=$(( $images % $servers ))
echo Images Per Segment $ips Remainder: $remainder

count=1
	for ((i=1 ; i<=$servers; i++)) ; 
	do
		echo "siftListsPerServer" loop number $i
			if [ "$remainder" -ge 1 ]
		then 
		# we still have a remainder
			add=1
		else 
		# we no longer have a remainder
			add=0
	fi	
		
	for ((j=1 ; j<= $(( $ips + $add )) ; j++))
		do echo $i $j
			#removed TESTLOCAL VAR
					sed -n "$count"p $IMG_LOG_DIR/img_list.txt >> siftlists/"$i"_siftlist.txt
				
						#sed -n "$count"p $IMG_LOG_DIR/img_list.txt >> siftlists/"$i"_siftlist.txt
			((count++))
		done
	((remainder--))
	done
# That's assuming each machine is the same speed!, otherwise we'll need load balancing!
}
								 #~ ██████  ▓██▓ 
								     #~ ▓▓ ▒█  █▒
								     #~ █  █░  ▒█
								    #~ ▒█  █    █
								    #~ █░  █  █ █
								   #~ ▒█   █    █
								   #~ █░   █░  ▒█
								  #~ ▒█    ▒█  █▒
								  #~ █▒     ▓██▓ 

								copyListsToRealServers () {
	
echo "In copyListsToRealServers"

j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1}'`
	for (( i=1; i <= $j ; i++ ))
		do
			CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt` 
			echo server $CURRENT_SERVER number $i

			scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$CLIENT_WORKDIR
		done
echo "leaving cLTRS"
}

#R
copyListsToFakeServers () {
	echo "In copyListsToFakeServers"
	

	j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1}'`
	for (( i=1; i <= $j ; i++ ))
		do
			CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt` 
			echo server $CURRENT_SERVER number $i
			cp -v $SOURCE_IMAGE_DIR/matchlist_$i.txt $CLIENT_LIST_DIR/fake_servers/$CURRENT_SERVER/

			cp -v $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CLIENT_LIST_DIR/fake_servers/$CURRENT_SERVER/
		done
echo "leaving cLTFS"
}

											              #~ 
								 #~ ░████░  ▓██▓ 
								 #~ █▒  ▒█ ▒█  █▒
								 #~ █    █ █░  ▒█
								 #~ █▒  ▒█ █    █
								  #~ ████  █  █ █
								 #~ █▒  ▓█ █    █
								 #~ █    █ █░  ▒█
								 #~ █▓  ▒█ ▒█  █▒
								 #~ ░████░  ▓██▓
								 				  
								startRealSifts () {

j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1 }'`

	for (( i=1 ; i <= $j ; i++)) ; do
		CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt`
		echo "Creating SiftSH for $CURRENT_SERVER"
		
		##### WHERE YO AT YO
		#echo cd "$HOME"/.aws/servers/fake_servers/"$CURRENT_SERVER"/ 	 > $JOBS_SET/"$i"_JOB.sh
		#echo "echo your pwd is: \$PWD" 									>> $JOBS_SET/"$i"_JOB.sh
		echo cd $CLIENT_WORKDIR > $JOBS_SET/"$i"_sift_JOB.sh
		echo VisualSFM siftgpu "$i"_siftlist.txt >> $JOBS_SET/"$i"_sift_JOB.sh
#		echo scpHome *.sift $SOURCE_IMAGE_DIR 	 >> $JOBS_SET/"$i"_sift_JOB.sh
		echo scp -i $SSH_KEY_C -r *.sift $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR >> $JOBS_SET/"$i"_sift_JOB.sh

	
		chmod +x $JOBS_SET/"$i"_sift_JOB.sh
		
		scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$SERVER_DIR/RENDER_SERVER/JOBS_SETUP/

		IN_FILE="$i"_sift_JOB.sh 
		ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $SERVER_DIR/RENDER_SERVER/JOBS_SETUP/\$RFILE $SERVER_DIR/RENDER_SERVER/JOBS_PENDING/\$RFILE"

#		scpToCueIp "$i"_JOB.sh $CURRENT_SERVER
		
		mv $JOBS_SET/"$i"_sift_JOB.sh $JOBS_DONE/
	done
}

#80R
startFakeSifts () {

j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1 }'`
for (( i=1 ; i <= $j ; i++))
do
CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt`
echo "Creating SiftSH for $CURRENT_SERVER"
echo VisualSFM siftgpu $HOME/.aws/servers/fake_servers/"$CURRENT_SERVER"/"$i"_siftlist.txt
echo cd "$HOME"/.aws/servers/fake_servers/"$CURRENT_SERVER"/ > $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh
echo "echo your pwd is: \$PWD" >> $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh
echo cd "$HOME"/.aws/servers/fake_servers/"$CURRENT_SERVER"/
echo VisualSFM siftgpu $HOME/.aws/servers/fake_servers/"$CURRENT_SERVER"/"$i"_siftlist.txt >> $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh
echo cp *.sift $SOURCE_IMAGE_DIR >> $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh
chmod +x $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh
mv $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_JOB.sh $HOME/RENDER_SERVER/JOBS_PENDING/

done
}

												              #~ 
								  #~ ███▓   ▓██▓ 
								 #~ █▓  █▒ ▒█  █▒
								 #~ █    █ █░  ▒█
								 #~ █    █ █    █
								 #~ █▓  ▓█ █  █ █
								  #~ ███▒█ █    █
								     #~ ▒█ █░  ▒█
								 #~ ▓  ▒█░ ▒█  █▒
								 #~ ▒███▒   ▓██▓ 				

								waitForSiftsToFinish () {

DIR_SIFTS=`ls -1 $SOURCE_IMAGE_DIR/*.sift 2>/dev/null | wc -l`
DIR_PEGS=`ls -1 $SOURCE_IMAGE_DIR/*.[jJ][pP][gG] | wc -l`
echo DIR_SIFTS= $DIR_SIFTS DIR_PEGS= $DIR_PEGS
#

while [ "$DIR_SIFTS" -lt "$DIR_PEGS" ]
do
    echo "Still not enought sifts back..."
    sleep 1
    DIR_SIFTS=`ls -1 $SOURCE_IMAGE_DIR/*.sift 2>/dev/null | wc -l`
    echo DIR_SIFTS = $DIR_SIFTS
done
echo "looks like yr done"

}

					                     
				#				 ███     ▓██▓   ▓██▓ 
				#				   █    ▒█  █▒ ▒█  █▒
				#				   █    █░  ▒█ █░  ▒█
				#				   █    █    █ █    █
				#				   █    █    █ █    █
				#				   █    █░  ▒█ █░  ▒█
				# 				   █    ▒█  █▒ ▒█  █▒
				#				 █████   ▓██▓   ▓██▓ 

								 getInverseSifts () {

j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1 }'`
for (( i=1 ; i <= $j ; i++)) ; do

CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt`
#sould become function (getLoopCurrentServerID#
	cat <<EOF > $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh
			cd $CLIENT_WORKDIR
			echo MY PWD IS... $PWD
			#rm getRemainingSifts.txt   
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
					#cp /media/ephemeral/\$i.sift . ;done 
					scp -i $SSH_KEY_C $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/\$i.sift . ;
					done
			rm .outlist_prext.txt
			#touch $SOURCE_IMAGE_DIR/got_sifts_$i
			ssh -i $SSH_KEY_C -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER	 "touch $SOURCE_IMAGE_DIR/got_sifts_$i"
EOF

	chmod +x $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh
	#mv $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_SIFT_MOVE_JOB.sh $HOME/RENDER_SERVER/JOBS_PENDING/

	scp -i $SSH_KEY $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh $CURRENT_SERVER:$SERVER_DIR/RENDER_SERVER/JOBS_SETUP/

	IN_FILE="$i"_SIFT_MOVE_JOB.sh
	ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $SERVER_DIR/RENDER_SERVER/JOBS_SETUP/\$RFILE $SERVER_DIR/RENDER_SERVER/JOBS_PENDING/\$RFILE"
	mv $JOBS_SET/"$i"_SIFT_MOVE_JOB.sh $JOBS_DONE/"$i"_SIFT_MOVE_JOB.sh
done

}
                
								# ███    ███     ▓██▓ 
								#   █      █    ▒█  █▒
								#   █      █    █░  ▒█
								#   █      █    █    █	
								#   █      █    █  █ █
								#   █      █    █    █
								#   █      █    █░  ▒█
								#   █      █    ▒█  █▒
								# █████  █████   ▓██▓ 

								 waitForSiftsToCopy () {
DOES_SIFT_EXIST=0
while [ "$DOES_SIFT_EXIST" -lt "$NUMBER_OF_SERVERS" ]
do 
    echo "Waiting for sifts to copy..."
    echo "DOES_SIFT_EXIST = $DOES_SIFT_EXIST"
DOES_SIFT_EXIST=`ls -1 $SOURCE_IMAGE_DIR/*got_sifts* 2>/dev/null | wc -l`
    sleep 1
done
echo "All Sifts at home exist"
}

								 #~ ███    ▒████   ▓██▓ 
								   #~ █    █▒  ▓█ ▒█  █▒
								   #~ █         █ █░  ▒█
								   #~ █        ▒█ █    █
								   #~ █       ░█▒ █  █ █
								   #~ █      ░█▒  █    █
								   #~ █     ▒█▒   █░  ▒█
								   #~ █    ▒█░    ▒█  █▒
								 #~ █████  ██████  ▓██▓ 

									getMatchListTotal () {


#iterate through each primary image
TOTALCOUNT=0

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
			#SECONDPAIR=`sed -n "$MATCHLOOP"p $IMG_LOG_DIR/img_list.txt`
			SECONDPAIR=${FILENAMEARRAY[$MATCHLOOP]}
			MAINPAIR=${FILENAMEARRAY[$c]}
			#MAINPAIR=`sed -n "$c"p $IMG_LOG_DIR/img_list.txt`
			#	if [ "$TESTLOCAL" -eq 0 ]
			#then 
				echo $MAINPAIR $SECONDPAIR >> $MATCH_LIST_DIR/.matchtmp.txt
			#else
			#echo $SOURCE_IMAGE_DIR/$MAINPAIR $SOURCE_IMAGE_DIR/$SECONDPAIR >> $MATCH_LIST_DIR/.matchtmp.txt
			#	fi		
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

#servers are benchmarked here to add to speed matching.
#declare -a BENCHMARK_SERVER=( 262 252 146 )
declare -a BENCHMARK_SERVER=( 50 100 125)

NUMBER_OF_SERVERS_BENCHMARK=${#BENCHMARK_SERVER[@]}
echo "Number of servers to benchmark" $NUMBER_OF_SERVERS_BENCHMARK
MATCH_TOTAL=0
MATCH_LIST=$MATCH_LIST_DIR/.matchtmp.txt
MATCH_LIST_TOTAL=`wc -l $MATCH_LIST | awk '{ print $1 }'`
END_LIST=$((MATCH_LIST_TOTAL - 1))

for (( i=0; i < $NUMBER_OF_SERVERS_BENCHMARK ; i++ ))
do
        k=${BENCHMARK_SERVER[$i]}
        ((MATCH_TOTAL=MATCH_TOTAL + k ));
done

START_LINE=1

for (( i=0; i < $NUMBER_OF_SERVERS_BENCHMARK ; i++))
do
        CURRENT_BENCHMARK=${BENCHMARK_SERVER[$i]}
	#num=$(echo 
        #num=`echo "($CURRENT_BENCHMARK / $MATCH_LIST_TOTAL)" | bc`
        #MATCH_CUT=`echo "($num * $MATCH_LIST_TOTAL)" | bc`
        #dFRAMES=`echo "($rFRAMES * $FPS)" | bc`

	num=$(echo "scale=5; $CURRENT_BENCHMARK / $MATCH_TOTAL" | bc)
        MATCH_CUT=$(echo "scale=1; $num * $MATCH_LIST_TOTAL" | bc);


	
	#num=$(echo "scale=5; $CURRENT_BENCHMARK / $TOTAL" | bc)
        #MATCH_CUT=$(echo "scale=1; $num * $MATCH_LIST_TOTAL" | bc);

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

CURRENT_SERVER=`sed -n "$INC_I"p $CLIENT_LIST_DIR/serverlist.txt`

echo "CS_END" 
echo scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_WORKDIR
scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$INC_I.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_WORKDIR

done

}
		
								 #~ ███    ▒████   ▓██▓ 
								   #~ █    █▒  ▓█ ▒█  █▒
								   #~ █         █ █░  ▒█
								   #~ █        ▒█ █    █
								   #~ █      ███░ █  █ █
								   #~ █        ▓█ █    █
								   #~ █         █ █░  ▒█
								   #~ █    █░  ▓█ ▒█  █▒
								 #~ █████  ▒████   ▓██▓ 

									makeMatchLists () {
getMatchListTotal

# make the lists for each server
for (( c=1; c<=$NUMBER_OF_SERVERS; c++ ))
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
CURRENT_SERVER=`sed -n "$c"p $CLIENT_LIST_DIR/serverlist.txt`
scp -i $SSH_KEY $SOURCE_IMAGE_DIR/matchlist_$c.txt $SFM_USERNAME@$CURRENT_SERVER:$CLIENT_WORKDIR

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


#adding a very basic load balancer to it...
# split image list into 20, then keep... 
# need to make the job dispatcher first.

NUMBER_OF_MATCHLISTS=20

j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1 }'`
for (( i=1 ; i <= $j ; i++ )) ; do 
#for (( i=1 ; i <= $NUMBER_OF_MATCHLISTS ; i++ )) ; do 
	CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt`

	cat <<EOF > $JOBS_SET/"$i"_MATCH_JOB.sh
	cd $CLIENT_WORKDIR
	echo "About to match from list"
	VisualSFM sfm+pairs+skipsfm . nomatch.nvm matchlist_$i.txt

	VisualSFM sfm+skipsfm+exportp . matches_out_$i.txt
	scp -i $SSH_KEY_C matches_out_$i.txt $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR/
	#cp matches_out_$i.txt $SOURCE_IMAGE_DIR/
EOF

	chmod +x $JOBS_SET/"$i"_MATCH_JOB.sh
	#mv $HOME/RENDER_SERVER/JOBS_SETUP/"$i"_MATCH_JOB.sh $HOME/RENDER_SERVER/JOBS_PENDING/
	scp -i $SSH_KEY $JOBS_SET/"$i"_MATCH_JOB.sh $CURRENT_SERVER:$SERVER_DIR/RENDER_SERVER/JOBS_SETUP/
	IN_FILE="$i"_MATCH_JOB.sh
	ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $SERVER_DIR/RENDER_SERVER/JOBS_SETUP/\$RFILE $SERVER_DIR/RENDER_SERVER/JOBS_PENDING/\$RFILE"

done
}
							
							
								  #~ ███    █████   ▓██▓ 
								   #~ █    █      ▒█  █▒
								   #~ █    █      █░  ▒█
								   #~ █    ████▒  █    █
								   #~ █       ░█▓ █  █ █
								   #~ █         █ █    █
								   #~ █         █ █░  ▒█
								   #~ █    █░  █▓ ▒█  █▒
								 #~ █████  ▒███▓   ▓██▓ 

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

copyFakeSiftsToHosts () {

:
# doing this in startFakeSifts function
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

for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do 
scp -i $SSH_KEY *.mat $i:$CLIENT_WORKDIR
#     for j in `ls -1 $SOURCE_IMAGE_DIR/*.mat`
#	do
#	scp -i dloud.pem $j $i:/media/ephemeral
#	done
done
}

#170R
copyMatchesToFakeServers () {

for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do 
     for j in `ls -1 $SOURCE_IMAGE_DIR/*.mat`
	do
	cp -v $j $CLIENT_LIST_DIR/fake_servers/$i
	done
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

echo "Tarring CMVS dirs"
echo "I am in directory..."  $PWD  "-- end PWD"

echo $CMVS_NAME
echo "STOPPING.... CTRL-C Me"
read Nothing


tar cf cmvs.tar $CMVS_NAME

for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do 
    #for j in `cat $IMG_LOG_DIR/img_list.txt` ;do	
    ssh-keygen -F "~/.ssh/known_hosts" -R $i 1>&2
		scp -i $SSH_KEY cmvs.tar $i:$CLIENT_WORKDIR &
		#scp -i $SSH_KEY $j $i:$CLIENT_WORKDIR
	#done
done
wait

count=1
for i in `cat $CLIENT_LIST_DIR/serverlist.txt`
do
		
			CURRENT_SERVER=`sed -n "$count"p $CLIENT_LIST_DIR/serverlist.txt` 
			echo server $CURRENT_SERVER number $i

			#scp -i $SSH_KEY $SOURCE_IMAGE_DIR/siftlists/"$i"_siftlist.txt $CURRENT_SERVER:$CLIENT_WORKDIR

			ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "cd $CLIENT_WORKDIR ; tar xf $CLIENT_WORKDIR/cmvs.tar &"
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
#generate pmvs job script
cat <<EOF > $JOBS_SET/$currentClusterOptionPLY
#!/bin/bash
cd ~/Pictures/sfmWorkDir/$CMVS_NAME
CPU_NUMBER=\$(cat ~/sfm/.maxThreads)
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
		

#       scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$SERVER_DIR/RENDER_SERVER/JOBS_SETUP/
#       IN_FILE="$i"_sift_JOB.sh
#       ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE 
#       mv $SERVER_DIR/RENDER_SERVER/JOBS_SETUP/\$RFILE $SERVER_DIR/RENDER_SERVER/JOBS_PENDING/\$RFILE"
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
						echo "Choosing $pmvsJobChoice to send to $firstMachineOnTheRank"
						#ssh-keygen -F "~/.ssh/known_hosts" -R $firstMachineOnTheRank
						scp -i $SSH_KEY  -o "StrictHostKeyChecking no" $pmvsJobChoice $SFM_USERNAME@$firstMachineOnTheRank:~/sfm/RENDER_SERVER/JOBS_PENDING/
						mv $pmvsJobChoice $JOBS_DONE/
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
cmvs $PROJECTNAME.nvm.cmvs/ maximage[=100] CPU[=4]

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
	#~ ▐   ▐ ▐ ▐▐▐ ▐▐▐ ▐ ▐ ▐ ▐      ▐  ▐ ▐ ▐ ▐ ▐    ▐   ▐  ▐ ▐ ▐ ▐  ▀▚ 
	#~ ▝▙▞ ▝▙▛ ▐▐▐ ▐▐▐ ▝▙▛ ▐ ▐      ▐  ▝▄▜ ▐ ▐ ▝▙▞  ▝▄ ▗▟▄ ▝▙▛ ▐ ▐ ▝▄▞ 

#~ 
#~ copyBackGlob () {
	#~ scp 'SERVERNAME:/DIR/\*' .
#~ }


clearTempDirs () {

echo "Clearing All remote store Directories"
for i in `cat $CLIENT_LIST_DIR/serverlist.txt` ;do 
# this line removes the ip from knownhosts to prevent a Spoof Login
    ssh-keygen -F "~/.ssh/known_hosts" -R $i

	ssh -i $SSH_KEY $SFM_USERNAME@$i "rm -vr ~/Pictures/sfmWorkDir/*"


done

}


clearAllJobs () {

echo "About to clean render directories"
for i in `cat $CLIENT_LIST_DIR/serverlist.txt` ; do 
	ssh-keygen -F "~/.ssh/known_hosts" -R $i
        ssh -i $SSH_KEY $SFM_USERNAME$i "rm -vr \$RENDER_SERVER/\$JOBS_PENDING/*; rm -vr \$RENDER_SERVER/JOBS_COMPLETED/* ; rm -vr \$RENDER_SERVER/JOBS_CUED/* ; rm -vr \$RENDER_SERVER/JOBS_SETUP/*" 
done
}


#### this is how it's meant to be done!!! oh well..
# j=`wc -l $CLIENT_LIST_DIR/serverlist.txt | awk '{ print $1 }'`
# 
# 	for (( i=1 ; i <= $j ; i++)) ; do
# 		CURRENT_SERVER=`sed -n "$i"p $CLIENT_LIST_DIR/serverlist.txt`
# 		echo "Creating SiftSH for $CURRENT_SERVER"
# 		
# 		##### WHERE YO AT YO
# 		#echo cd "$HOME"/.aws/servers/fake_servers/"$CURRENT_SERVER"/ 	 > $JOBS_SET/"$i"_JOB.sh
# 		#echo "echo your pwd is: \$PWD" 									>> $JOBS_SET/"$i"_JOB.sh
# 		echo cd $CLIENT_WORKDIR > $JOBS_SET/"$i"_sift_JOB.sh
# 		echo VisualSFM siftgpu "$i"_siftlist.txt >> $JOBS_SET/"$i"_sift_JOB.sh
# #		echo scpHome *.sift $SOURCE_IMAGE_DIR 	 >> $JOBS_SET/"$i"_sift_JOB.sh
# 		echo scp -i $SSH_KEY_C -r *.sift $SFM_USERNAME@$MASTER_SERVER:$SOURCE_IMAGE_DIR >> $JOBS_SET/"$i"_sift_JOB.sh
# 
# 	
# 		chmod +x $JOBS_SET/"$i"_sift_JOB.sh
# 		
# 		scp -i $SSH_KEY $JOBS_SET/"$i"_sift_JOB.sh $CURRENT_SERVER:$SERVER_DIR/RENDER_SERVER/JOBS_SETUP/
# 
# 		IN_FILE="$i"_sift_JOB.sh 
# 		ssh -i $SSH_KEY $SFM_USERNAME@$CURRENT_SERVER "RFILE=$IN_FILE ; mv $SERVER_DIR/RENDER_SERVER/JOBS_SETUP/\$RFILE $SERVER_DIR/RENDER_SERVER/JOBS_PENDING/\$RFILE"
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

