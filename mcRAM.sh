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

# Add $pwd variable.
# Bash trap "^C" to print "/stop" to minecraft for proper shutdown.
# Remove connected.status file.  Same thing can be achieved by correct operation order.
# Backups:
	# Start with check for connected user.
	# Begin sleep for however long is necessary.
	# Run backup and start loop again.
		# Largest potential issue is if java subshell is terminated.
		# Perhaps run backup before closing if this is the case.
# Sync:
	# Not sure whether to have sync on java subshell close, or just have thread terminate
	#   and have java subshell's final sync be good enough.
# Use sed regex instead of awk.
# Clean up greps, see if it is possible to avoid them.
# Find more efficient PID tracking method that doesnt require pgrep | grep several times per second. - possibly finished
# Consider real logging method where all output is passed upwards but filtered last minute by designation.
# 	perhaps integrate real log levels like debug, notice, warning, and error.
# Make an array of files that this script needs to access and check permissions more effectively.
# If server.properties does not exist but minecraft server jar does, try initial run procedures.
	# Not sure what initial run procedures will be. Will need to know when first world generation is complete.
	# Perhaps: if "world" name specified but folder is empty, make the volatile symlink but dont move anything.
# IF recovering from poor shutdown, do not touch anything.  Instead look for most recently modified world files, alert user, and quit.

##############################################################
####        Don't Change Anything Below this point        ####
##############################################################
SERVER_PROPERTIES_WORLD=$(sed -ne 's/level-name=//p' $(pwd)/server.properties)
PIPE_SUFFIX=$SERVER_PROPERTIES_WORLD-$(date --rfc-3339=ns | awk -F. '{print $2}').pipe
INPIPE=input-to-minecraft-$PIPE_SUFFIX
OUTPIPE=output-from-minecraft-$PIPE_SUFFIX

mkfifo $OUTPIPE;

exec 5<>$OUTPIPE;

cat $OUTPIPE &
# Must be cat. Tail will not work with named pipes.
CATPID=$!;


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
	echo "Server JAR file does not exist." > $OUTPIPE
	exit 1
fi

WORLD_DIRNAME=$(pwd)

WORLD=$WORLD_DIRNAME/world_storage

SETTINGS=$(find $WORLD_DIRNAME -name server.properties)

VOLATILE=$WORLD_DIRNAME/$SERVER_PROPERTIES_WORLD

WORLD_IN_RAM=/dev/shm/$VOLATILE

TTY=$(tty)

BACKUP_FULL_LINK=${BACKUP_PATH}/${SERVER_PROPERTIES_WORLD}_full.tgz

if [ "$V" == yes ]; then
	echo "Creating directory structure." > $OUTPIPE
fi

if [[ ! -d $WORLD  ]]; then
        if ! mkdir -p $WORLD; then
               echo "$WORLD does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
               exit 1 #FAIL :(
        fi
fi

if [[ ! -d $VOLATILE  ]]; then
        if ! mkdir -p $VOLATILE; then
                echo "$VOLATILE does not exist and I could not create the directory! Permissions maybe?"  > $OUTPIPE
                exit 1 #FAIL :(
        fi
fi

if [[ ! -d $WORLD_IN_RAM  ]]; then
        if ! mkdir -p $WORLD_IN_RAM; then
                echo "$WORLD_IN_RAM does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
                exit 1 #FAIL :(
        fi
fi

if [[ ! -d $BACKUP_PATH  ]]; then
        if ! mkdir -p $BACKUP_PATH; then
                echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
                exit 1 #FAIL :(
        fi
fi

 if [ "$V" == yes ]; then
	echo "Copying original world to perminent world storage." > $OUTPIPE
fi

if [ "$V" == yes ];
	then rsync -rav $VOLATILE/ $WORLD  > $OUTPIPE
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
	echo 'Removing any leftover lockfiles. (In case of destroyed process)' > $OUTPIPE
fi

if [ "$V" == yes ];
	then rm $WORLD/session.lock $WORLD_DIRNAME/server.log.lck $VOLATILE/session.lock  > $OUTPIPE
	else rm -f $WORLD/session.lock $WORLD_DIRNAME/server.log.lck $VOLATILE/session.lock
fi

if [ "$V" == yes ]; then
	echo 'Removing old symlinks. (In case of destroyed process)' > $OUTPIPE
fi

# Temp disabling deletions
#################rm -rf $VOLATILE 2>&1 > /dev/null
# This should use "unlink". I think.

#Clean anything World that was left on the RAM
if [ "$V" == yes ]; then
	echo 'Clearing any leftover RAM junk. (In case of destroyed process)' > $OUTPIPE
fi

# Temp disabling deletions
#################rm -rf $WORLD_IN_RAM 2>&1 > /dev/null

#Setup folder in RAM for the world to be loaded
if ! mkdir -p $WORLD_IN_RAM; then
        echo "$WORLD_IN_RAM does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
        exit 1 #FAIL :(
fi

if [ "$V" == yes ]; then
	echo "Copying $WORLD backup to $WORLD_IN_RAM." > $OUTPIPE
fi
cp -aR $WORLD/* $WORLD_IN_RAM/

if [ "$V" == yes ]; then
	echo "Entering directory $WORLD_DIRNAME."  > $OUTPIPE
fi
cd $WORLD_DIRNAME

echo "Linking $VOLATILE to $WORLD_IN_RAM" > $OUTPIPE
ln -s $WORLD_IN_RAM $VOLATILE

if [ "$V" == yes ]; then
	echo "Starting perminent minecraft world $WORLD with RAM link to $VOLATILE." > $OUTPIPE
fi

mkfifo $INPIPE
############################
# BENNING of java subshell #
############################
# tail -f $INPIPE | $(java -server -Xms2048M -Xmx2048M -Djava.net.preferIPv4Stack=true -jar $SERVER nogui > $OUTPIPE

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

tail -f $INPIPE | $(
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
	-jar $SERVER nogui >&5 2>&1;

sleep 3
# I HATE sleep statements but its needed to prevent file collisions. Minecraft or java will claim to be terminated when files are still being modified.
# I spent a while lowering this as much as possible while retaining its dependability.
if [ "$V" == yes ];
	then
		echo "Syncing RAM and permanent storage."
		rsync -ravP --delete --force "$WORLD_IN_RAM/" "$WORLD"
	else rsync -ravPq --delete --force "$WORLD_IN_RAM/" "$WORLD"
fi
#################rm -rf $VOLATILE
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

# Temp disabling deletions
#################rm -rf $WORLD_IN_RAM
echo "Original state restored." > $OUTPIPE

kill -15 $(pgrep -f $INPIPE)
rm $INPIPE
kill -15 $$
) &
JAVA_SUBSHELL_PID=$!;
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

while [ -d /proc/$JAVA_SUBSHELL_PID ];do
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
			echo "say User presence logged" > $INPIPE
		fi
	else
	        CONNECTION==0
	fi

	# This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
        SECONDS_TO_SLEEP=60;
        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
                sleep 1;
                if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
                        exit 0;
                fi
        done
done &

while [ -d /proc/$JAVA_SUBSHELL_PID ];do
   # smart sync
	if [[ -a $CONNECTIONFILE ]]
	then
		echo "save-on" > $INPIPE
		echo "save-all" > $INPIPE
		echo "save-off" > $INPIPE
		# Think about keeping saving on all the time and only disabling it immediately before a sync.
		rsync -ravq --delete --force "$WORLD_IN_RAM/" "$WORLD"
		echo "say RAM Sync complete." > $INPIPE
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
                if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
                        exit 0;
                fi
        done
done &

while [ -d /proc/$JAVA_SUBSHELL_PID ];do

	if [[ -a $BACKUP_SINCE_USER_CONNECTION ]]; then
		# force sync and backup
	        echo "save-on" > $INPIPE
	        echo "save-all" > $INPIPE
	        echo "save-off" > $INPIPE
	        rsync -ravq --delete --force "$WORLD_IN_RAM/" "$WORLD"
	        echo "say RAM Sync complete." > $INPIPE
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
#################	                rm ${existingbackups[0]};
	                unset existingbackups[0];
	                existingbackups=( "${existingbackups[@]}" );
	                POTENTIAL_SIZE=$(($(du -s $BACKUP_PATH | awk '{ print $1 }') + $(du -s $WORLD_IN_RAM | awk '{ print $1 }')));
	        done
	        if [[ ! -d $BACKUP_PATH  ]]; then
	                if ! mkdir -p $BACKUP_PATH; then
	                        echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
	                        exit 1 #FAIL :(
	                fi
	        fi
		unset existingbackups;
		DATE=$(date +%Y-%m-%d-%Hh%M)
	        BACKUP_FILENAME=$SERVER_PROPERTIES_WORLD-$DATE-full.tgz
	        tar -czhf $BACKUP_PATH/$BACKUP_FILENAME $WORLD >/dev/null 2>&1
#################	        rm -f $BACKUP_FULL_LINK
	        ln -s $BACKUP_FILENAME $BACKUP_FULL_LINK
		echo "say -Backup synchronization complete.-" > $INPIPE
		rm $BACKUP_SINCE_USER_CONNECTION
		renice -n -10 -p $MCPID >/dev/null 2>&1

	        # This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
	        SECONDS_TO_SLEEP=10800;
	        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
	                sleep 1;
	                if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
	                        exit 0;
	                fi
	        done

	else
	        # This could be cleaned up, no need for PID checks at the beginning AND end of the loop.
	        SECONDS_TO_SLEEP=10800;
	        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
	                sleep 1;
	                if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
	                        exit 0;
	                fi
	        done
	fi
done &

TRACK_JAVA_SUBSHELL_PID=1;
while [ $TRACK_JAVA_SUBSHELL_PID == 1 ]; do
        if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
                sleep 1;
        else
                kill -15 $CATPID >/dev/null 2>&1;
		rm $OUTPIPE;
                TRACK_JAVA_SUBSHELL_PID=0;
        fi
done &

# This is clearly not working
while read input; do
#	echo $input > $INPIPE
	print $input > $INPIPE
done
