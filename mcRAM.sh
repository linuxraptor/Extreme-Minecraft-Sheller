#!/bin/bash
# Title: MCRAM
# Author: Koodough, Linuxraptor
# NO WARRANTIES YOU CREEPER

# From minecraft.sh startup script
# screen -dmS $SCREEN_NAME java -server -Xmx${MEMMAX}M -Xms${MEMALOC}M -Djava.net.preferIPv4Stack=true $SERVER_OPTIONS -jar minecraft_server.jar nogui
#
# From backup script - searching for the screen to command.
# screen -S $SCREEN_NAME -p 0 -X stuff "$(printf "say Backing up the map in 10s\r")"

# INSTALL
# Place this file in the folder where minecraft server lies.
#To see the console of the minecraft server type "screen -xRRA" in terminal

#SERVER_JAR=craftbukkit-0.0.1-SNAPSHOT.jar
SERVER_JAR=minecraft_server.jar








###########################################################
# You can optionally change these, but it isnt necessary. #
###########################################################

BACKUP_PATH=$(pwd)/automatic_backups
MAX_BACKUP_FILES=6
MAX_BACKUP_PATH_SIZE_MB=2000

##############################################
### Don't Change Anything Below this point ###
##############################################


if [[ $# -gt 0 ]]
        then
                case "$1" in
                        "-v")
                                V=yes;
                                ;;
                        "--verbose")
                                V=yes;
                                ;;
		esac
fi

if [ "$V" == yes ]; then
	echo "VERBOSITY: ON"
fi

if [ "$V" == yes ]; then
	echo "Setting variables."
fi

SERVER=$(pwd)/$SERVER_JAR

if [[ ! -f $SERVER ]]; then
	echo "Server JAR file does not exist. Attempting to download." > $TTY
	wget "https://s3.amazonaws.com/MinecraftDownload/launcher/minecraft_server.jar" $WORLD_DIRNAME/minecraft_server.jar
	if [[ ! -f $SERVER ]]; then
		echo "Fuck it. I cannot download this correctly." > $TTY
		exit 1
	fi
fi

WORLD_DIRNAME=$(pwd)

WORLD=$WORLD_DIRNAME/world_storage

SETTINGS=$(find $WORLD_DIRNAME -name server.properties)

###############################################################################################################################3
#if [[ ! -f $SETTINGS ]]; then
	SERVER_PROPERTIES_WORLD=world
	#PIPE=world-$(date --rfc-3339=ns | awk -F. '{print $2}').pipe
	#mkfifo $PIPE
	#tail -f $PIPE | $(java -server -Xms2048M -Xmx2048M -Djava.net.preferIPv4Stack=true -jar $SERVER nogui > /dev/null & )
	#sleep 5
	#echo "stop" > $PIPE
        #kill -15 $(pgrep -f $PIPE)
        #rm $PIPE
	#while read input; do
	#        echo $input > $PIPE
	#done
	##kill -15 $(pgrep -fl $SERVER | awk -F' ' '{print $1}')
#else
#	SERVER_PROPERTIES_WORLD=$(cat $SETTINGS | grep level-name= | awk -F= '{print $2}')
#fi

VOLATILE=$WORLD_DIRNAME/$SERVER_PROPERTIES_WORLD

WORLD_IN_RAM=/dev/shm/$VOLATILE

TTY=$(tty)

BACKUP_FULL_LINK=${BACKUP_PATH}/${SERVER_PROPERTIES_WORLD}_full.tgz

if [ "$V" == yes ]; then
	echo "Creating directory structure." > $TTY
fi

if [[ ! -d $WORLD  ]]; then
        if ! mkdir -p $WORLD; then
               echo "$WORLD does not exist and I could not create the directory! Permissions maybe?" > $TTY
               exit 1 #FAIL :(
        fi
fi

if [[ ! -d $VOLATILE  ]]; then
        if ! mkdir -p $VOLATILE; then
                echo "$VOLATILE does not exist and I could not create the directory! Permissions maybe?"  > $TTY
                exit 1 #FAIL :(
        fi
fi

if [[ ! -d $WORLD_IN_RAM  ]]; then
        if ! mkdir -p $WORLD_IN_RAM; then
                echo "$WORLD_IN_RAM does not exist and I could not create the directory! Permissions maybe?" > $TTY
                exit 1 #FAIL :(
        fi
fi

if [[ ! -d $BACKUP_PATH  ]]; then
        if ! mkdir -p $BACKUP_PATH; then
                echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?" > $TTY
                exit 1 #FAIL :(
        fi
fi

 if [ "$V" == yes ]; then
	echo "Copying original world to perminent world storage." > $TTY
fi

if [ "$V" == yes ];
	then rsync -ravu $VOLATILE/ $WORLD  > $TTY
	else rsync -ravuq $VOLATILE/ $WORLD
fi

if [ $(file world | awk -F' ' {'print $2'}) == directory ];
	then
		OLD_BACKUPS=$VOLATILE"-backup-*" # I have to do this stupid shit because using the expression directly
		rm -rf $OLD_BACKUPS              # in rm causes the wildcard to be ignored.
		mv $VOLATILE $VOLATILE"-backup-"$(date +%Y-%m-%d-%Hh%M)
	else
		screen -wipe
fi
if [ "$V" == yes ]; then
	echo 'Removing any leftover lockfiles. (In case of destroyed process)' > $TTY
fi

if [ "$V" == yes ];
	then rm $WORLD/session.lock $WORLD_DIRNAME/server.log.lck $VOLATILE/session.lock  > $TTY
	else rm -f $WORLD/session.lock $WORLD_DIRNAME/server.log.lck $VOLATILE/session.lock
fi

if [ "$V" == yes ]; then
	echo 'Removing old symlinks. (In case of destroyed process)' > $TTY
fi
rm -rf $VOLATILE 2>&1 > /dev/null

#Clean anything World that was left on the RAM
if [ "$V" == yes ]; then
	echo 'Clearing any leftover RAM junk. (In case of destroyed process)' > $TTY
fi
rm -rf $WORLD_IN_RAM 2>&1 > /dev/null

#Setup folder in RAM for the world to be loaded
if ! mkdir -p $WORLD_IN_RAM; then
        echo "$WORLD_IN_RAM does not exist and I could not create the directory! Permissions maybe?" > $TTY
        exit 1 #FAIL :(
fi

if [ "$V" == yes ]; then
	echo "Copying $WORLD backup to $WORLD_IN_RAM." > $TTY
fi
cp -aR $WORLD/* $WORLD_IN_RAM/

if [ "$V" == yes ]; then
	echo "Entering directory $WORLD_DIRNAME."  > $TTY
fi
cd $WORLD_DIRNAME

echo "Linking $VOLATILE to $WORLD_IN_RAM" > $TTY
ln -s $WORLD_IN_RAM $VOLATILE

#if [ "$V" == yes ]; then
#	echo "Starting perminent minecraft world $WORLD with RAM link to $VOLATILE." > $TTY
#fi

rm -f $WORLD_DIRNAME/*.pipe
PIPE=$SERVER_PROPERTIES_WORLD-$(date --rfc-3339=ns | awk -F. '{print $2}').pipe
mkfifo $PIPE
############################
# BENNING of java subshell #
############################
tail -f $PIPE | $(java -server -Xms2048M -Xmx2048M -Djava.net.preferIPv4Stack=true -jar $SERVER nogui > /dev/null
# Pipe to dev null because java output overflows into BASH sometimes, it needs to stay in the pipeline.
sleep 3
if [ "$V" == yes ];
	then
		echo "Syncing RAM and permanent storage."
		rsync -ravuP --delete --force "$WORLD_IN_RAM/" "$WORLD"
	else rsync -ravuPq --delete --force "$WORLD_IN_RAM/" "$WORLD"
fi
rm -rf $VOLATILE
if ! mkdir -p $VOLATILE; then
        echo "Couldn't move perminent world back to original location. Permissions maybe?"
        exit 1
fi
if [ "$V" == yes ];
        then
		echo "Restoring original world location"
		rsync -ravu --delete --force $WORLD_IN_RAM/ $VOLATILE
        else rsync -ravuq --delete --force $WORLD_IN_RAM/ $VOLATILE
fi

rm -rf $WORLD_IN_RAM
echo "Original state restored." > $TTY

kill -15 $(pgrep -f $PIPE)
rm $PIPE
kill -15 $$) &
########################
# END of java subshell #
########################
sleep 5
LEAD_PID=$$
MCPID=$(pgrep -lf $SERVER | awk -F' ' '{print $1}' && sleep 1)
sleep 1
MCPORT=$( lsof -i 4 -a -p $MCPID | awk 'NR==2' | awk '{ print $(NF-1) }' |  awk -F':' '{ print $2 }' | awk -F'-' '{print $1}' )
DATE=$(date +'%Y-%m-%d %X')
CONNECTIONFILE=/tmp/$MCPID.status

while [[ -n $(pgrep -fl $0 | grep $LEAD_PID) ]];do
   # connection check
	PLAYERS=$( netstat -an  inet | grep $MCPORT | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' );
	if [[ -n $PLAYERS ]]
	        then
	        if [[ -a $CONNECTIONFILE ]]
		        then
	                CONNECTION==1 # Unnecessary because of connected.status file, but neat to see live output
	        else
	                touch $CONNECTIONFILE
	                CONNECTION==1
			echo "say User presence logged" > $PIPE
		fi
	else
	        CONNECTION==0
	fi
	sleep 60
done &

while [[ -n $(pgrep -fl $0 | grep $LEAD_PID) ]];do
   # smart sync
	if [[ -a $CONNECTIONFILE ]]
	then
		echo "save-on" > $PIPE
		echo "save-all" > $PIPE
		echo "save-off" > $PIPE
		rsync -ravuq --delete --force "$WORLD_IN_RAM/" "$WORLD"
		echo "say RAM Sync complete." > $PIPE
	        PLAYERS=$( netstat -an  inet | grep $MCPORT | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' );
	        if [[ -n $PLAYERS ]]
	                then
	                CONNECTION==1 # Unnecessary because of connected.status file, but neat to see live output
	        else
	                CONNECTION==0
	                rm $CONNECTIONFILE
	        fi
	fi
	sleep 300
done &

while [[ -n $(pgrep -fl $0 | grep $LEAD_PID) ]];do
   # force sync and backup
        echo "save-on" > $PIPE
        echo "save-all" > $PIPE
        echo "save-off" > $PIPE
        rsync -ravuq --delete --force "$WORLD_IN_RAM/" "$WORLD"
        echo "say RAM Sync complete." > $PIPE
        SIZE_IN_BYTES=$(du -s $BACKUP_PATH | awk '{ print $1 }');
        MAX_BYTE_SIZE=$((1000 * $MAX_BACKUP_PATH_SIZE_MB));
        POTENTIAL_SIZE=$(($(du -s $BACKUP_PATH | awk '{ print $1 }') + $(du -s $VOLATILE | awk '{ print $1 }')));
        declare -a existingbackups
        for f in $(echo $(find $BACKUP_PATH -size +1M | sort -g))
	        do
                existingbackups=( "${existingbackups[@]}" "$f" );
        done
        while [[ $POTENTIAL_SIZE -gt $MAX_BYTE_SIZE && -n ${existingbackups[0]} ]]
	        do
                rm ${existingbackups[0]};
                unset existingbackups[0];
                existingbackups=( "${existingbackups[@]}" );
                POTENTIAL_SIZE=$(($(du -s $BACKUP_PATH | awk '{ print $1 }') + $(du -s $WORLD_IN_RAM | awk '{ print $1 }')));
        done
        if [[ ! -d $BACKUP_PATH  ]]; then
                if ! mkdir -p $BACKUP_PATH; then
                        echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?" > $TTY
                        exit 1 #FAIL :(
                fi
        fi
        DATE=$(date +%Y-%m-%d-%Hh%M)
        BACKUP_FILENAME=$SERVER_PROPERTIES_WORLD-$DATE-full.tgz
        tar -czhf $BACKUP_PATH/$BACKUP_FILENAME $WORLD >/dev/null 2&>1
        rm -f $BACKUP_FULL_LINK
        ln -s $BACKUP_FILENAME $BACKUP_FULL_LINK
	echo "say -Backup synchronization complete." > $PIPE
	sleep 10800
done &

while read input; do
	echo $input > $PIPE
done

#Reniceing helps the soul, just like a bowl of chicken soup.
# renice -n -10 -p `ps -e | grep java | awk '{ print $1 }'`
