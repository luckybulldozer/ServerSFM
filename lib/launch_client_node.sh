#!/bin/bash
# ex ffmxf_server_local.sh
# (no input args)
# Created by devteam on 20/05/13.
# Copyright 2013 LuckyBulldozer.com. All rights reserved.

#job watcher script os x sfmCloud
LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
echo "launcher says libdir= $LIBDIR"

source $LIBDIR/dsCommon.lib.sh
source $LIBDIR/server-sfm.lib.sh
initVars

#legacy --- to delete seems to work!
#initClientDirs

FULLHOSTNAME=`getLocalIP`



#trap exit
trap '{ echo "Exiting, removing from idle and online states"; 
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$FULLHOSTNAME" ;
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $HAVE_LAUNCHED_DIR/$FULLHOSTNAME" ; 
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $SERVER_CLIENTS_LIST_DIR/$FULLHOSTNAME" ; 
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "sed -i'.bk' 's/'${FULLHOSTNAME}'//g' $SERVERS_CLIENT_LIST"; 
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "sed -i'.bk' '/^$/d' $SERVERS_CLIENT_LIST"; 
ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $SERVERS_CLIENT_LIST.bk"; 
exit 1; }' INT


# work out if we have been issued a max thread count
if [[ -z $1 ]]
		then maxThreads=`sysctl hw.ncpu | awk '{print $2}'`
	else
		maxThreads=$1
	fi
echo $maxThreads > $RENDER_SERVER/maxThreads


echo $FULLHOSTNAME > $HAVE_LAUNCHED_DIR/$FULLHOSTNAME	
#this sorta works...

ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "echo $FULLHOSTNAME >> $SERVERS_CLIENT_LIST" 


#let the master server see that we have launched - putting them into the IDLE_DIR
scp -i $SSH_KEY $HAVE_LAUNCHED_DIR/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR
scp -i $SSH_KEY $HAVE_LAUNCHED_DIR/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$HAVE_LAUNCHED_DIR

# a local version of above...
echo $FULLHOSTNAME > $IDLE_DIR/$FULLHOSTNAME
scp -i $SSH_KEY -r $IDLE_DIR/$FULLHOSTNAME $SFM_USERNAME@$MASTER_SERVER:$IDLE_DIR/$FULLHOSTNAME

#make sure there are no file in JOBS_COMPLETED


#probably not needed...
cd $RENDER_SERVER

ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $BUSY_DIR/$FULLHOSTNAME; touch $IDLE_DIR/$FULLHOSTNAME"	

#Infinite Loop
while true
	 do
		printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script. ."
				# Find Number of Jobs in JOBS_PENDING Directory
		workToDo=`ls -1 $JOBS_PENDING/*.sh 2>/dev/null| wc -l`

		## Job Processing Loop
		while [ $workToDo -gt 0 ]
			do

			
			i=0;	
			for jc in `ls -1 $JOBS_PENDING/*.sh 2>/dev/null`; 
				do 
				jobsPending[i]="${jc##*/}"
				((i++)) 
			done
	
			
			#assign first job in jobPending to jobProcessing
			jobsProcessing=${jobsPending[0]};
	
			if [[ -z $jobsProcessing ]]
				then 
					echo "No job to Process"
				else
					mv $JOBS_PENDING/$jobsProcessing $JOBS_PROCESSING/$jobsProcessing
				fi

			echo "jobsPending is... " ${jobsPending[@]}
			echo "jobsProcessing is... "$jobsProcessing
			echo "jobsComplete is... "${jobsComplete[@]}

			
			numPending=${#jobsPending[@]}
			if [[ $numPending -gt 0 ]] ; 
			then 
				echo "There are jobs to do..."
				jobsProcessing=${jobsPending[0]}
				jobsPending=( `remove 0 ${jobsPending[*]}` )
				# set state to busy
				ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $IDLE_DIR/$FULLHOSTNAME; touch $BUSY_DIR/$FULLHOSTNAME"
				#execute task
				$JOBS_PROCESSING/$jobsProcessing 2>/dev/null
					if [ $? -eq 0 ] ; 
						then 
							echoGood "Task Complete" ; 
							jobsComplete+=(${jobsProcessing}) 
							unset jobsProcessing
							end=(${!jobsComplete[@]})
							end=${end[@]: -1}
							echo $end
							mv $JOBS_PROCESSING/${jobsComplete[$end]} $JOBS_COMPLETE/${jobsComplete[$end]}
						else 
							echoBad "Task Failed! - moving to jobs/client/failed/" ;
							mv $JOBS_PROCESSING/$jobsProcessing $JOBS_FAILED/$jobsProcessing
							unset jobsProcessing
							ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $BUSY_DIR/$FULLHOSTNAME; touch $IDLE_DIR/$FULLHOSTNAME"
					fi
				ssh -i $SSH_KEY $SFM_USERNAME@$MASTER_SERVER "rm $BUSY_DIR/$FULLHOSTNAME; touch $IDLE_DIR/$FULLHOSTNAME"
				workToDo=0
			fi			
			
		done
   sleep .1
   printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script..."
   sleep .2
   printf "\r$FULLHOSTNAME - Threads = $maxThreads Waiting for render script .."
   sleep .2
   done
	
	
done
#head back to begining of loop



