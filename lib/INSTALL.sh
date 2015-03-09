#!/bin/bash
# this sets up serverSFM


echo " Welcome to..."
echo "                                   _____ ________  ___";
echo "   ________  ______   _____  _____/ ___// ____/  |/  /";
echo "  / ___/ _ \/ ___/ | / / _ \/ ___/\__ \/ /_  / /|_/ / ";
echo " (__  )  __/ /   | |/ /  __/ /   ___/ / __/ / /  / /  ";
echo "/____/\___/_/    |___/\___/_/   /____/_/   /_/  /_/   ";
echo "                                                      ";
echo "                                    INSTALLER v0.1    ";


LIBDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
echo "Installer says libdir= $LIBDIR"
source $LIBDIR/dsCommon.lib.sh
SSFM_INSTALL_DIR="$(dirname "$LIBDIR")"

editPrefs mainHost $(hostname).local
editPrefs ssfmInstallDir $SSFM_INSTALL_DIR


function setupWelcome () {
cat <<EOF

Since this is a pretty early beta of the software, the system installs into the archive directory.  It seems this is best at the moment!  This folder set up will also be in the same place on clients.

EOF
echoBad "Hit enter to keep going, otherwise hit CTRL-C now to cancel"
read nothing

}


function setupWorkdir () {
cat <<EOF

Please enter a directory for you main machine to install data it will frequently use?  This is the job cues etc.  Should be on your fastest disk, also may generate a few gig of data each time used."
EOF

SERVER_WORKDIR=$(expand_tilde $SSFM_INSTALL_DIR)
mkdir -p $SERVER_WORKDIR
editPrefs serverWorkDir $SERVER_WORKDIR
}

function setupUsername () {
USER_NAME=`whoami`
echoGood "The installer will use \"$(echoBad `whoami`)\", this the username that logs into your servers."
editPrefs username $USER_NAME
echo ""
}

function setupClientList () {
CLIENT_LIST=$SERVER_WORKDIR/jobs/server/clients/clientlist.txt
echo "Enter the name of your clients, including your local host if you want that to be used, otherwise it it will not be used for some of the processes."
echoGood "Include the domain, eg myClient.local"
echoBad "Put each client name on a new line, an empty line (ENTER) will finish the addition of new clients and move on."

NEW_CLIENT="empty"
NUMBER_OF_CLIENTS=0
until [ -z $NEW_CLIENT ]
	do
	   read NEW_CLIENT
	   ((NUMBER_OF_CLIENTS++))
	   if [ -z "$NEW_CLIENT" ]
		then
			echo "Thanks, servers added (add more in $CLIENT_LIST)"
		else
			echo "Checking to see if SSH is enabled on that server"
			echo "SSH TEST from serverSFM" | nc $NEW_CLIENT 22 > /dev/null
				if [ $? -eq 0 ] 
				   then
					echo $NEW_CLIENT >> $CLIENT_LIST
					CLIENT_LIST_VAR=$CLIENT_LIST_VAR" "$NEW_CLIENT
					echoGood "Added client $NEW_CLIENT - keep entering client names or just ENTER to move on"
				   else
					echoBad "Client may not exist at that name or SSH isn't enabled"  	
				fi	
           fi
	   
	done
 echo "All registered clients: $CLIENT_LIST_VAR"

CLIENT_LIST_VAR=$(echo $CLIENT_LIST_VAR | sed 's/ /,/g' )
editPrefs clientNames $CLIENT_LIST_VAR
}


function setupSSHKeys () {
echo "Thanks `echoGood $USER_NAME`, now we have to set up your ssh authentiction key."
echo "You have 2 options here, we can make an SSH key for you, or you can provide your own."
echo "Either enter the name and location of your SSH key e.g. ~/.ssh/yourkey.pem (tab completion will work), otherwise leave blank to generate the key. This will set up a key in your .ssh folder unless otherwise specified."
echoBad "SSH Key Location or ENTER to set one up"
read -e SSH_KEY
SSH_KEY_TILDE=$(expand_tilde "$SSH_KEY")
SSH_KEY=$SSH_KEY_TILDE
	
	#if we have an SSH Key Or Not
	#if we don't
	if [ -z $SSH_KEY ] ; then
		SSH_KEY=~/.ssh/serverSFM
		ssh-keygen -b 2048 -t rsa -f $SSH_KEY -q -N ""
		KEYCODE=`cat $SSH_KEY.pub`
		echoGood "Copying SSH key to remote clients"
		echoBad "You will need to enter the password and accept yes to the authentication"
			for i in `cat $CLIENT_LIST` ; do
				echoGood "Connecting to $i"
				ssh -q $i "mkdir ~/.ssh 2>/dev/null; chmod 700 ~/.ssh; echo "$KEYCODE" >> ~/.ssh/authorized_keys; chmod 644 ~/.ssh/authorized_keys"  && echoGood $host "ssh keys working." || echoBad $host "ssh keys not working=["			
			done
	# if we do
	else
		#if that really exists or not
		if [ -e $SSH_KEY ] 
			then
			echo "Checking your file is a valid SSH Key"					
			grep "BEGIN RSA PRIVATE KEY" $SSH_KEY > /dev/null
					#check that file really is a private key
					#if it is
					if [ $? -eq 0 ] 
						then
						echo "Looks like a valid SSH Key"
						editPrefs sshKey $SSH_KEY
					#else it isn't
					else
						grep "ssh-" $SSH_KEY > /dev/null
							#check if it's the pub instead
							if [ $? -eq 0 ] 
								then
								echo "Suspected Public Key (.pub), please add Private Key (.pem or no extension)"
								exit 1
							else
								echo "I have no idea what kind of file this is! Next step will probably fail"
								exit 1
							fi
					fi
				#if we get to this loop the we're trusting the user provided key works
				for i in `cat $SERVER_LIST` ; do
					echo "Using key $SSH_KEY"
					ssh -i $SSH_KEY $USER_NAME@$i exit
					echo $?
				done
		else
				echo "That file for your ssh key does not exist."
				exit 1
		fi				
	fi

editPrefs sshKey $SSH_KEY
}


function setupClientDirs () {
CLIENT_WORKDIR=$SERVER_WORKDIR/jobs/client/
echo ""
echoGood "All client image and SFM processing will happen in your client work directory which is set to $CLIENT_WORKDIR "
editPrefs clientWorkDir $CLIENT_WORKDIR


echo "Copying folder structure to remote clients"
find $SERVER_WORKDIR -type d 
find $SERVER_WORKDIR -type d > $SERVER_WORKDIR/lib/folderStructure.tmp
read nothing

echoGood "Setting up work directories on clients." 

clientListPrefs=`readPrefs clientNames`
for i in `echo $clientListPrefs` ; 
	do  
		if [[ "$i" == `hostname` ]] ; 
			then echo "is host" ; 
		else 
			echo "copy to: $i" ;
			ssh -i $SSH_KEY $USER_NAME@$i "mkdir $SERVER_WORKDIR"
				
				for j in `cat $SERVER_WORKDIR/lib/folderStructure.tmp` ; 
					do  ssh -i $SSH_KEY $USER_NAME@$i "mkdir $j"
				done

		fi 
done

}


function setupExit () {

cat <<EOF 

Thanks, that's all for now.

EOF

}


setupWelcome
setupWorkdir
setupUsername
#setupClientList
#setupSSHKeys
SSH_KEY=~/.ssh/ServerSFM
setupClientDirs
setupExit
