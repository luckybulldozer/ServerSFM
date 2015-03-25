#!/bin/bash
# ex ffmxf_server_local.sh
# (no input args)
# Created by devteam on 20/05/13.
# Copyright 2013 LuckyBulldozer.com. All rights reserved.

#job watcher script os x sfmCloud

#Start Up... Move incomplete jobs from JOBS CUED TO JOBS PENDING...


#   -o BatchMode=yes -o StrictHostKeyChecking=no


##init
LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
echo "launcher says libdir= $LIBDIR"
source $LIBDIR/dsCommon.lib.sh
source $LIBDIR/server-sfm.lib.sh

initVars
initClientDirs

# work out if we have been issued a max thread count
	if [[ -z $1 ]]
		then maxThreads=`sysctl hw.ncpu | awk '{print $2}'`
	else
		maxThreads=$1
	fi
echo $maxThreads > $CLIENT_WORKDIR/.maxThreads





FULLHOSTNAME=`hostname`
#is this were we expect SERVER_CLIENTS_LIST_DIR

#old echo $FULLHOSTNAME > ~/sfm/serverID/$FULLHOSTNAME
echo $FULLHOSTNAME > $SERVERS_CLIENT_LIST/$FULLHOSTNAME	

#scp -i $SSH_KEY -r ~/sfm/serverID/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:~/sfm/online_servers/
scp -i $SSH_KEY -r $SERVER_CLIENT_LIST/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$HOSTS_ONLINE


#echo $LOCALHOSTNAME > ~/sfm/serverID/$LOCALHOSTNAME
#scp -i $SSH_KEY -r ~/sfm/serverID/$LOCALHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$LOCALHOSTNAME

echo $LOCAL_HOSTNAME > $HOSTS_ONLINE/$LOCAL_HOSTNAME
scp -i $SSH_KEY -r $HOSTS_ONLINE/$LOCAL_HOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$LOCAL_HOSTNAME





# trap '{ echo "Exiting, removing from idle and online states"; ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$LOCALHOSTNAME" ; ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $sfm/online_servers/$FULLHOSTNAME" ; exit 1; }' INT




RENDER_SERVER=$CLIENT_WORKDIR/jobs/client/
JOBS_PENDING=$RENDER_SERVER/pending/
JOBS_CUED=$RENDER_SERVER/cued/
JOBS_COMPLETED=$RENDER_SERVER/completed/
JOBS_PENDING=$RENDER_SERVER/pending/
OUTPUT_FOLDER=$RENDER_SERVER/completed/




#move cued jobs back to pending on startup
mv $RENDER_SERVER/cued/* $JOBS_PENDING/ #2>/dev/null
#make sure there are new directories incase we are in a new location
#   we should have all these...
#echo "about to makedirs.."
#mkdir -p $RENDER_SERVER/JOBS_SETUP $RENDER_SERVER/JOBS_PENDING $RENDER_SERVER/JOBS_CUED/ $RENDER_SERVER/JOBS_COMPLETED

cd $RENDER_SERVER
#Begin Main Loop
while true
 do
	printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script. ."
	# Find Number of Jobs in JOBS_PENDING Directory
	WORKTODO=`ls -1 $JOBS_PENDING/* 2>/dev/null| wc -l`
		while [ $WORKTODO -gt 0 ]
			do
			#echo "IN THE LOOP"
			# Re-Init JOBS_CUE
			rm -r $JOBS_PENDING/JOBS_CUE
			# Rebuild the JOBS_CUE (No longer randome selection)
			for jc in `ls -1 $JOBS_PENDING/* 2>/dev/null`; do basename $jc >>$JOBS_PENDING/JOBS_CUE; done
			
			#choose JOB
			head -1 .$JOBS_PENDING/JOBS_CUE > $JOBS_PENDING/.JOB_CHOICE
			#Init Variable
			CHOOSE_JOB=`cat $JOBS_PENDING/.JOB_CHOICE`
			echo "Working on..." $CHOOSE_JOB
			# Move job from PENDING TO CUED
			mv $JOBS_PENDING/$CHOOSE_JOB $RENDER_SERVER/cued/$CHOOSE_JOB
			#Tell Server we're busy by removing ourself from IDLE_DIR
			ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$LOCALHOSTNAME"
			# Execute Job Script
			$JOBS_CUED/$CHOOSE_JOB 
			if [ $? -eq 0 ]
				then 
				#on Job Completion, Move Job to COMPLETED
				mv $JOBS_CUED/$CHOOSE_JOB $JOBS_COMPLETED
				# build in number of retries
			
				# add machine to HOSTS_IDLE
				scp -i $SSH_KEY -r $SERVERS_CLIENT_LIST/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$FULLHOSTNAME
			fi 
				##hack to find out if it's being exiting non zero...
				#scp -i $SSH_KEY -r ~/sfm/serverID/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR
			#Find out nubmer of remaining Jobs for WORKTODO variable
			WORKTODO=`ls -1 $JOBS_PENDING/* 2>/dev/null| wc -l `
			echo "$WORKTODO"
			#find jobs that are in JOBS_SETUP
					
			done
   sleep .1
   #HALFWIDTH=$(($COLUMNS / 2 ))
   #eval "printf '. %.0s' {1..$COLUMNS}"
   #printf "\rWaiting for render script.. "
   sleep .2
   printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script..."
   sleep .2
   printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script .."
   sleep .2
   done
	
	
done
#head back to begining of loop



