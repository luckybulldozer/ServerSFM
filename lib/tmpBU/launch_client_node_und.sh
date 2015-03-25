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


if [[ -z $1 ]]
then maxThreads=`sysctl hw.ncpu | awk '{print $2}'`
else
maxThreads=$1
fi

# naughty way to do it, but will work atleast!

echo $maxThreads > $CLIENT_WORKDIR/.maxThreads


echo "SERVER_POSTFIX="$SERVER_POSTFIX
LOCALHOSTNAME=`scutil --get LocalHostName`; echo $LOCALHOSTNAME
FULLHOSTNAME="$LOCALHOSTNAME$SERVER_POSTFIX"

echo $FULLHOSTNAME > ~/sfm/serverID/$FULLHOSTNAME
scp -i $SSH_KEY -r ~/sfm/serverID/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:~/sfm/online_servers/
echo $LOCALHOSTNAME > ~/sfm/serverID/$LOCALHOSTNAME
scp -i $SSH_KEY -r ~/sfm/serverID/$LOCALHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$LOCALHOSTNAME



# trap '{ echo "Exiting, removing from idle and online states"; ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$LOCALHOSTNAME" ; ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $sfm/online_servers/$FULLHOSTNAME" ; exit 1; }' INT

RENDER_SERVER=$HOME/sfm/RENDER_SERVER
JOBS_PENDING=$RENDER_SERVER/JOBS_PENDING/


OUTPUT_FOLDER=$RENDER_SERVER/JOBS_COMPLETED
#RENDER_SERVER=`cat ~/.dsw/RENDER_SERVER_VAR`  # now sourced from ~/ds_common.lib

#move cued jobs back to pending on startup
mv RENDER_SERVER/JOBS_CUED/* RENDER_SERVER/JOBS_PENDING/ 2>/dev/null
#make sure there are new directories incase we are in a new location
echo "about to makedirs.."
mkdir -p $RENDER_SERVER/JOBS_SETUP $RENDER_SERVER/JOBS_PENDING $RENDER_SERVER/JOBS_CUED/ $RENDER_SERVER/JOBS_COMPLETED
cd $RENDER_SERVER
#Begin Main Loop
while true
 do
	printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script. ."
	# Find Number of Jobs in JOBS_PENDING Directory
	WORKTODO=`ls -1 JOBS_PENDING/* 2>/dev/null| wc -l`
		while [ $WORKTODO -gt 0 ]
			do
			#echo "IN THE LOOP"
			# Re-Init JOBS_CUE
			rm -r .JOBS_CUE
			# Rebuild the JOBS_CUE (No longer randome selection)
			for jc in `ls -1 JOBS_PENDING/* 2>/dev/null`; do basename $jc >>.JOBS_CUE; done
			#head -$((${RANDOM} % `wc -l < .JOBS_CUE` + 1)) .JOBS_CUE | tail -1 > .JOB_CHOICE
			#choose JOB
			head -1 .JOBS_CUE > .JOB_CHOICE
			#Init Variable
			CHOOSE_JOB=`cat .JOB_CHOICE`
			echo "Working on..." $CHOOSE_JOB
			# Move job from PENDING TO CUED
			mv JOBS_PENDING/$CHOOSE_JOB JOBS_CUED/$CHOOSE_JOB
			#Tell Server we're busy by removing ourself from IDLE_DIR
			ssh -i $SSH_KEY -o "StrictHostKeyChecking no" $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$LOCALHOSTNAME"
			# Execute Job Script
			JOBS_CUED/$CHOOSE_JOB 
			if [ $? -eq 0 ]
				then 
				#on Job Completion, Move Job to COMPLETED
				mv JOBS_CUED/$CHOOSE_JOB JOBS_COMPLETED/
				# build in number of retries
			
				# add machine to HOSTS_IDLE
				scp -i $SSH_KEY -r ~/sfm/serverID/$LOCALHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$LOCALHOSTNAME
			fi 
				##hack to find out if it's being exiting non zero...
				#scp -i $SSH_KEY -r ~/sfm/serverID/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR
			#Find out nubmer of remaining Jobs for WORKTODO variable
			WORKTODO=`ls -1 JOBS_PENDING/* 2>/dev/null| wc -l `
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



