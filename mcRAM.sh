#!/bin/bash
##############################################################
# Title: MCRAM                                               #
# Author: Linuxraptor                                        #
# Contributors: Koodough, Crunchmuffin                       #
# NO WARRANTIES YOU CREEPER                                  #
# Place this file in the folder where minecraft server lies. #
##############################################################

##############################################################
#        Choose the server that you currently use.           #
##############################################################


#SERVER_JAR=craftbukkit-0.0.1-SNAPSHOT.jar
SERVER_JAR=minecraft_server.jar








##############################################################
#  You can optionally change these, but it isnt necessary.   #
##############################################################

BACKUP_PATH=$(pwd)/automatic_backups
MAX_BACKUP_FILES=6
MAX_BACKUP_PATH_SIZE_MB=100



##############################################################
#                          TODO                              #
##############################################################

# Maybe turn this into perl, it's getting nasty and desperately needs regex instead of awk.
# ...Even if it isnt perl, it still needs regex instead of awk.
# Clean up greps
# Find more efficient PID tracking method that doesnt require pgrep | grep several times per second.
# Consider real logging method where all output is passed upwards but filtered last minute by designation.
# 	perhaps integrate real log levels like debug, notice, warning, and error.
# Make an array of files necessary to access to check permissions quickly and with far less code.
# Remove initial minecraft setup attempts, it is far too broken. Replace with quick java subshell that waits and closes.
# 	Perhaps edit eula, but really, it should be removed maintaining it is a lot of work and minecraft server is constantly changing version names.

##############################################################
####        Don't Change Anything Below this point        ####
##############################################################


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
	then rsync -rav $VOLATILE/ $WORLD  > $TTY
	else rsync -ravq $VOLATILE/ $WORLD
fi

if [ $(file $VOLATILE | awk -F' ' {'print $2'}) == directory ];
	# If minecraft is stopped correctly, "world" will be a directory. If not, it will still be a symlink.
	# This looks at the filetype and determines if the old backups need to remain due to an incorrect termination.
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

if [ "$V" == yes ]; then
	echo "Starting perminent minecraft world $WORLD with RAM link to $VOLATILE." > $TTY
fi

rm -f $WORLD_DIRNAME/*.pipe
PIPE=$SERVER_PROPERTIES_WORLD-$(date --rfc-3339=ns | awk -F. '{print $2}').pipe
mkfifo $PIPE
############################
# BENNING of java subshell #
############################
# tail -f $PIPE | $(java -server -Xms2048M -Xmx2048M -Djava.net.preferIPv4Stack=true -jar $SERVER nogui > $TTY

# rem IntelliJ's suggested options for 64-bit java.exe
# set /E /S JAVA_OPTIONS=-Xms128m -Xmx750m -XX:MaxPermSize=350m -XX:ReservedCodeCacheSize=96m -ea -Dsun.io.useCanonCaches=false -Djava.net.preferIPv4Stack=true -Djsse.enableSNIExtension=false -$
# http://mindprod.com/jgloss/javaexe.html#JAVAOPTIONS
# http://java-latte.blogspot.in/2014/03/metaspace-in-java-8.html
# jstat program can be used to monitor jre performance: https://www.java.net/node/692654
# still investigating "ReservedCodeCacheSize", ive been told this param can hurt more than it helps in newer java, where dynamic allocation works well:
# http://stackoverflow.com/questions/7513185/what-are-reservedcodecachesize-and-initialcodecachesize
# sun.io.useCanonCaches=false - disable problematic caches, ensure compatibility with new garbage collection
# jsse.enableSNIExtension=false - disable problematic SSL implementation
# parallel garbage collection! we still use "stop-the-world" garbage collection because the "concurrent" options can decrease performance by 40%.
# with "stop-the-world" garbage collection we can still keep pauses below 100ms.
# http://stackoverflow.com/questions/2101518/difference-between-xxuseparallelgc-and-xxuseparnewgc
# https://themindstorms.wordpress.com/2009/01/21/advanced-jvm-tuning-for-low-pause/
# https://blogs.oracle.com/jonthecollector/entry/our_collectors

# -Dcom.sun.management.jmxremote.port=55555
# this allows for remote java management console plug-ins. good for performance tweaking.
# JMX management controlled by these local files:
# /opt/oracle-jre-bin-1.8.0.45/lib/management/jmxremote.access (check out this file for help, it is thorough)
# /opt/oracle-jre-bin-1.8.0.45/lib/management/jmxremote.password (this file will not exist yet)
# more info here:
# https://jazz.net/help-dev/clm/index.jsp?re=1&topic=/com.ibm.jazz.repository.web.admin.doc/topics/t_server_mon_tomcat_option2.html&scope=null

tail -f $PIPE | $(
	java \
	-server \
	-Xms2048M \
	-Xmx2048M \
	-ea \
	-XX:+UseG1GC \
	-XX:+UseStringDeduplication \
	-XX:+DisableExplicitGC \
	-XX:MetaspaceSize=85M \
	-Djava.net.preferIPv4Stack=true-ea \
	-Djava.net.preferIPv4Addresses \
	-Dsun.io.useCanonCaches=false \
	-Djsse.enableSNIExtension=false \
	-jar $SERVER nogui > $TTY

sleep 3
# I HATE sleep statements but it's needed to prevent file collisions. Minecraft or java will claim to be terminated when files are still being modified.
# I spent a while lowering this as much as possible while retaining its dependability.
if [ "$V" == yes ];
	then
		echo "Syncing RAM and permanent storage."
		rsync -ravP --delete --force "$WORLD_IN_RAM/" "$WORLD"
	else rsync -ravPq --delete --force "$WORLD_IN_RAM/" "$WORLD"
fi
rm -rf $VOLATILE
if ! mkdir -p $VOLATILE; then
        echo "Couldn't move perminent world back to original location. Permissions maybe?"
        exit 1
fi
if [ "$V" == yes ];
        then
		echo "Restoring original world location"
		rsync -rav --delete --force $WORLD_IN_RAM/ $VOLATILE
        else rsync -ravq --delete --force $WORLD_IN_RAM/ $VOLATILE
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
MCPID=$(pgrep -f $SERVER && sleep 1)
sleep 1
# MCPID needs to be padded with sleep statements or it becomes seriously unstable. I'm not too bothered by this;
# it only gets called once.
MCPORT=$( lsof -i 4 -a -p $MCPID | awk 'NR==2' | awk '{ print $(NF-1) }' |  awk -F':' '{ print $2 }' | awk -F'-' '{print $1}' )
DATE=$(date +'%Y-%m-%d %X')
CONNECTIONFILE=/tmp/$MCPID.status
BACKUP_SINCE_USER_CONNECTION=/tmp/$MCPID.recentbackup

while [[ -n $(pgrep -f $0 | grep $LEAD_PID) ]];do
   # connection check
	PLAYERS=$( netstat -an  inet | grep $MCPORT | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' );
	if [[ -n $PLAYERS ]]
	        then
	        if [[ -a $CONNECTIONFILE ]]
		        then
	                CONNECTION==1 # Unnecessary because of connected.status file, but neat to see live output
	        else
	                touch $CONNECTIONFILE
			touch $BACKUP_SINCE_USER_CONNECTION
	                CONNECTION==1
			echo "say User presence logged" > $PIPE
		fi
	else
	        CONNECTION==0
	fi

	# This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
        SECONDS_TO_SLEEP=60;
        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
                sleep 1;
                if [[ ! -n $(pgrep -f $0 | grep $LEAD_PID) ]]; then
                        exit 0;
                fi
        done
done &

while [[ -n $(pgrep -f $0 | grep $LEAD_PID) ]];do
   # smart sync
	if [[ -a $CONNECTIONFILE ]]
	then
		echo "save-on" > $PIPE
		echo "save-all" > $PIPE
		echo "save-off" > $PIPE
		# Think about keeping saving on all the time and only disabling it immediately before a sync.
		rsync -ravq --delete --force "$WORLD_IN_RAM/" "$WORLD"
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

        # This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
        SECONDS_TO_SLEEP=300;
        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
                sleep 1;
                if [[ ! -n $(pgrep -f $0 | grep $LEAD_PID) ]]; then
                        exit 0;
                fi
        done
done &

while [[ -n $(pgrep -f $0 | grep $LEAD_PID) ]];do

	if [[ -a $BACKUP_SINCE_USER_CONNECTION ]]
		# force sync and backup
	        echo "save-on" > $PIPE
	        echo "save-all" > $PIPE
	        echo "save-off" > $PIPE
	        rsync -ravq --delete --force "$WORLD_IN_RAM/" "$WORLD"
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
		unset existingbackups;
		DATE=$(date +%Y-%m-%d-%Hh%M)
	        BACKUP_FILENAME=$SERVER_PROPERTIES_WORLD-$DATE-full.tgz
	        tar -czhf $BACKUP_PATH/$BACKUP_FILENAME $WORLD >/dev/null 2>&1
	        rm -f $BACKUP_FULL_LINK
	        ln -s $BACKUP_FILENAME $BACKUP_FULL_LINK
		echo "say -Backup synchronization complete.-" > $PIPE
		rm $BACKUP_SINCE_USER_CONNECTION
		renice -n -10 -p $MCPID >/dev/null 2>&1

	        # This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
	        SECONDS_TO_SLEEP=10800;
	        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
	                sleep 1;
	                if [[ ! -n $(pgrep -f $0 | grep $LEAD_PID) ]]; then
	                        exit 0;
	                fi
	        done

	else
	        # This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
	        SECONDS_TO_SLEEP=10800;
	        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
	                sleep 1;
	                if [[ ! -n $(pgrep -f $0 | grep $LEAD_PID) ]]; then
	                        exit 0;
	                fi
	        done
	fi
done &

while read input; do
	echo $input > $PIPE
done
