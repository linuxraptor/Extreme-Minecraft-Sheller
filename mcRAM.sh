#!/bin/bash
##############################################################
# Title: MCRAM                                               #
# Author: Chris Kienstra                                     #
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

DIRNAME=$(pwd)
BACKUP_PATH=$DIRNAME/automatic_backups
MAX_BACKUP_FILES=6
MAX_BACKUP_PATH_SIZE_MB=100



##############################################################
#                          TODO                              #
##############################################################

# Script is pretty intolerant to directories not existing yet.
	# Need to make early rsync commands conditional. If source content exists, sync.
	# Maybe necessary directory creation can be part of the permission checking array and loop.
# Maybe make rsync options a variable? So all can be changed at once?
# Revise variable names, many of them are redundant or do not make any sense.
# Add more comments.
# Bash trap "^C" to print "/stop" to minecraft for proper shutdown.
# Add "-A" to rsync options. This preserves ACLs.
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
# 	perhaps integrate real log levels like debug, notice, warning, and error.
# Make an array of files that this script needs to access and check permissions more effectively.
# If server.properties does not exist but minecraft server jar does, try initial run procedures.
	# Not sure what initial run procedures will be. Will need to know when first world generation is complete.
	# Perhaps: if "world" name specified but folder is empty, make the volatile symlink but dont move anything.
# IF recovering from poor shutdown, do not touch anything.  Instead look for most recently modified world files, alert user, and quit.
# Functions. And classes. And objects. And things that resemble a real program, not just a one-shot script.
# Consider real logging method where all output is passed upwards but filtered last minute by designation.
# Determine if double-brackets are always necessary in each conditional statement.
# Finally, make a script to reconnect to lost minecraft sessions.
	# If you run the script and minecraft is already running, exit.
	# For a more advanced feature, prompt if user would like to reconnect to running session: (Y/n)?
# The reason we need a function for things like creating a backup is so I can create a thread that looks like:
	# Sleep for a while, check PID status, run_backup();.
	# I have to call it in a few places already and it would be WAY easier this way.


##############################################################
####        Don't Change Anything Below this point        ####
##############################################################
SERVER_PROPERTIES_WORLD=$(sed -ne 's/level-name=//p' $DIRNAME/server.properties)
PIPE_SUFFIX=$(date +%F_%H:%M:%S.%N).pipe
INPIPE=$DIRNAME/input-to-minecraft-$PIPE_SUFFIX
OUTPIPE=$DIRNAME/output-from-minecraft-$PIPE_SUFFIX

mkfifo $OUTPIPE;

# This is where the output pipe magic happens.
# We are opening a reading and writing file descriptor named "5".
# (<) Reading so minecraft can print output to it.
# (>) Writing so it can pass those commands to our STDOUT.
# This matters because we want the ability to modify the file descriptor later to
# Write to a new TTY STDOUT in case we lose our console connection to minecraft.
# The normal read and write file descriptors (0 and 1) typically cannot be connected to new
# inputs and outputs once they are bound to a certain STDIN and STDOUT
# without a call made by a lower level language. It might be more possible
# if I experimented with exec further.
# More info about exec here:
# http://pubs.opengroup.org/onlinepubs/009604599/utilities/exec.html#tag_04_46_17
# and here:
# http://stackoverflow.com/questions/18351198/what-are-the-uses-of-the-exec-command-in-shell-scripts
# More info about C-level proc calls here:
# https://github.com/jerome-pouiller/reredirect

# "Using file descriptor 5 might cause problems. When Bash creates a child process, as with exec, the child inherits fd 5":
# http://www.tldp.org/LDP/abs/html/io-redirection.html
# exec 5<>$OUTPIPE; 

exec 4<>$OUTPIPE;

# Must be cat. While "tail" works printing information TO named pipes,
# it does not work printing output FROM named pipes.
# This command connects our minecraft output pipe to our TTY STDOUT.
# I need to find a more intelligent way of terminating this.
# This is the only thread in this program that cannot terminate itself intelligently.
cat $OUTPIPE &

# Now we record what PID to kill when the script is ending.
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


SERVER_EXECUTABLE=$DIRNAME/$SERVER_JAR

if [[ ! -f $SERVER_EXECUTABLE ]]; then
	echo "Server JAR file does not exist." > $OUTPIPE
	exit 1
fi

COPY_OF_WORLD=$DIRNAME/world_storage

MINECRAFT_WORLD=$DIRNAME/$SERVER_PROPERTIES_WORLD

# We are going to place our RAM symlink on top of our minecraft world directory.
# It is not necessary to copy the $MINECRAFT_WORLD variable but it makes
# things more readable.
MINECRAFT_WORLD_SYMLINK_TO_RAM=$MINECRAFT_WORLD

WORLD_IN_RAM=/dev/shm/$SERVER_PROPERTIES_WORLD

BACKUP_FULL_LINK=${BACKUP_PATH}/${SERVER_PROPERTIES_WORLD}_full.tgz

if [ "$V" == yes ]; then
	echo "Creating directory structure." > $OUTPIPE
fi

if [[ ! -d $COPY_OF_WORLD  ]]; then
        if ! mkdir -p $COPY_OF_WORLD; then
               echo "Could not create directory: $COPY_OF_WORLD. Permissions maybe?" > $OUTPIPE
               exit 1 #FAIL :(
        fi
fi

# This probably should not be trying to make a dir where the world might already exist.
#if [[ ! -d $MINECRAFT_WORLD  ]]; then
#        if ! mkdir -p $MINECRAFT_WORLD; then
#                echo "$MINECRAFT_WORLD does not exist and I could not create the directory! Permissions maybe?"  > $OUTPIPE
#                exit 1 #FAIL :(
#        fi
#fi

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
	echo "Copying original world to $COPY_OF_WORLD." > $OUTPIPE
fi

if [ "$V" == yes ];
	then rsync -ravA $MINECRAFT_WORLD/ $COPY_OF_WORLD  > $OUTPIPE
	else rsync -ravAq $MINECRAFT_WORLD/ $COPY_OF_WORLD
fi

# Is this necessary? To have world_storage and this?

#if [ $(file $MINECRAFT_WORLD | awk -F' ' {'print $2'}) == directory ];
	# If minecraft is stopped correctly, "world" will be a directory. If not, it will still be a symlink.
	# This looks at the filetype and determines if the old backups need to remain due to an incorrect termination.
#	then
#		OLD_BACKUPS=$MINECRAFT_WORLD"-backup-*" # I have to do this stupid shit because using the expression directly
#		rm -rf $OLD_BACKUPS              # in rm causes the wildcard to be ignored.
#		mv $MINECRAFT_WORLD $MINECRAFT_WORLD"-backup-"$(date +%Y-%m-%d-%Hh%M)
		# rsync -ravmPq --delete $MINECRAFT_WORLD $MINECRAFT_WORLD"-backup-"$(date +%Y-%m-%d-%Hh%M)
#	else
#		screen -wipe
#fi

if [ "$V" == yes ]; then
	echo 'Removing any leftover lockfiles. (In case of destroyed process)' > $OUTPIPE
fi

# This used to be necessary.  Minecraft would leave lock files all over the place and error out
# when a new session was created.  It seems lock files are still left all over the place by Minecraft
# but it no longer cares.  Perhaps I should remove this, but I will leave it as long as Minecraft
# is abondoning those files and not cleaning them up on termination.
#if [ "$V" == yes ];
#	then rm $COPY_OF_WORLD/session.lock $DIRNAME/server.log.lck $MINECRAFT_WORLD/session.lock  > $OUTPIPE
#	else rm -f $COPY_OF_WORLD/session.lock $DIRNAME/server.log.lck $MINECRAFT_WORLD/session.lock
#fi

if [ "$V" == yes ]; then
	echo 'Removing old symlinks. (In case of destroyed process)' > $OUTPIPE
fi

#Setup folder in RAM for the world to be loaded
if ! mkdir -p $WORLD_IN_RAM; then
        echo "$WORLD_IN_RAM does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
        exit 1 #FAIL :(
fi

#############################################################################
# Copy directly from "$WORLD" instead of "$COPY_OF_WORLD".
if [ "$V" == yes ]; then
	echo "Copying $MINECRAFT_WORLD to $WORLD_IN_RAM." > $OUTPIPE
fi
rsync -ravAPq $MINECRAFT_WORLD/* $WORLD_IN_RAM/


# I dont think this is necessary either since we use fully-qualified filenames.
if [ "$V" == yes ]; then
	echo "Entering directory $DIRNAME."  > $OUTPIPE
fi
cd $DIRNAME

# THIS is where we first use our minecraft world's symlink!
# Symlinks can sit "on top" of directories, meaning: after this command,
# the minecraft world will be a symlink, but the orignal minecraft world directory still exists.
# The directory is simply hidden.
# We can unlink without consequence and the directory will appear once again.

echo "Linking $MINECRAFT_WORLD to $WORLD_IN_RAM" > $OUTPIPE
#ln -s $WORLD_IN_RAM $MINECRAFT_WORLD_SYMLINK_TO_RAM
# So it turns out that ln wont make a link over an existing directory
# ...but mount will! 
mount -o bind $WORLD_IN_RAM $MINECRAFT_WORLD_SYMLINK_TO_RAM

if [ "$V" == yes ]; then
	echo "Starting minecraft world $COPY_OF_WORLD with RAM link to $MINECRAFT_WORLD_SYMLINK_TO_RAM." > $OUTPIPE
fi

mkfifo $INPIPE

############################
# BENNING of java subshell #
############################

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
	-jar $SERVER_EXECUTABLE nogui >&$OUTPIPE 2>&1
	#                              ^
	# Redirects file descriptor 1 (STDOUT) to $OUTPIPE, then 2 (STDERR) to 1.
	# This allows both STDOUT and STDERR to get piped into the $OUTPIPE.
	# More info here: http://www.tldp.org/LDP/abs/html/io-redirection.html

# This shouldnt be necessary but world files have been modified shortly after minecraft termination.
# This ensures their safety before rsync. This only happens when minecraft is killed incorrectly.
while [[ ! -z $(lsof +D $MINECRAFT_WORLD) ]]; do
	sleep 0.1;
	echo "Waiting for world files to be released." > $OUTPIPE
done

if [ "$V" == yes ];
	then
		echo "Syncing RAM and permanent storage." > $OUTPIPE
		rsync -ravAP --delete "$WORLD_IN_RAM/" "$COPY_OF_WORLD" > $OUTPIPE
	else rsync -ravAPq --delete "$WORLD_IN_RAM/" "$COPY_OF_WORLD" > $OUTPIPE
fi

#unlink $MINECRAFT_WORLD_SYMLINK_TO_RAM
# See above reasoning for changing this from a symlink to a mountpoint.
umount $MINECRAFT_WORLD_SYMLINK_TO_RAM 

# Now we can remove our world files in RAM.  We will do this with our
# final rsync using --remove-source-files.
if [ "$V" == yes ];
        then
		echo "Restoring original world location" > $OUTPIPE
		rsync -ravA --delete --remove-source-files $WORLD_IN_RAM/ $MINECRAFT_WORLD > $OUTPIPE
        else rsync -ravAq --delete --remove-source-files $WORLD_IN_RAM/ $MINECRAFT_WORLD > $OUTPIPE
fi

# Backup old IFS before changing it.
ORIGINAL_IFS=$IFS
IFS=$'\n'
# Delete (only) empty directories left in RAM. Trying to be as safe as possible.
# The "sort -r" seems unnecessary but it has a purpose.
# By default, "find" lists results from the shallowest depth and goes deeper.
# We need to list directories in the deepest depth and get more shallow.
# This way we dont try to remove any directories that contain subdirectories.
for EMPTY_RAM_DIRECTORY in $(find $WORLD_IN_RAM/ -type d | sort -r)
	do 
	rmdir $EMPTY_RAM_DIRECTORY
done
IFS=$ORIGINAL_IFS

echo "Original state restored." > $OUTPIPE

# Kill the "tail" command connects the input pipe to minecraft.
kill -15 $(pgrep -f "tail -f $INPIPE")

# Delete the input pipe.
rm $INPIPE

# This exists to kill the "while read input" loop at the end of the script.
# Currently it will only exit after the shell has terminated AND enter is pressed.
# This is because "while read" is triggered at the end of each line processed.
kill -15 $$;
) &
JAVA_SUBSHELL_PID=$!;
########################
# END of java subshell #
########################
LEAD_PID=$$

if [ "$V" == yes ]; then
	echo "Waiting for java to claim a PID." > $OUTPIPE
fi
while [ -z $(printf "$(pgrep -f $SERVER_EXECUTABLE)") ]; do
	sleep 0.1;
done

MCPID=$(pgrep -f $SERVER_EXECUTABLE)
# MCPID needs to be padded with sleep statements or it becomes seriously unstable. I'm not too bothered by this;
# it only gets called once and it does not delay playability, just background threads.

if [ "$V" == yes ]; then
	echo "Waiting for minecraft server to claim a port." > $OUTPIPE
fi
while [ -z $(lsof -i 4 -a -p $MCPID -P -Fn | sed -ne 's/^[^:]*://p') ]; do
	sleep 0.1;
done

#MCPORT=$( lsof -i 4 -a -p $MCPID | awk 'NR==2' | awk '{ print $(NF-1) }' |  awk -F':' '{ print $2 }' | awk -F'-' '{print $1}' )
MCPORT=$(lsof -i 4 -a -p $MCPID -P -Fn | sed -ne 's/^[^:]*://p')
DATE=$(date +'%Y-%m-%d %X')
CONNECTIONFILE=/tmp/$MCPID.status
BACKUP_SINCE_USER_CONNECTION=/tmp/$MCPID.needs_backup

while [ -d /proc/$JAVA_SUBSHELL_PID ];do
   # connection check
	#PLAYERS=$( netstat -an  inet | grep $MCPORT | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' ); # This one returns the IP address of one player. Fun but unnecessary.
	PLAYERS=$( netstat -an  inet | grep $MCPORT | grep ESTABLISHED );
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
		rsync -ravAq --delete "$WORLD_IN_RAM/" "$COPY_OF_WORLD"
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
	        rsync -ravAq --delete "$WORLD_IN_RAM/" "$COPY_OF_WORLD"
	        echo "say RAM Sync complete." > $INPIPE
	        SIZE_IN_BYTES=$(du -s $BACKUP_PATH | awk '{ print $1 }');
	        MAX_BYTE_SIZE=$((1000 * $MAX_BACKUP_PATH_SIZE_MB));
	        POTENTIAL_SIZE=$(($(du -s $BACKUP_PATH | awk '{ print $1 }') + $(du -s $MINECRAFT_WORLD | awk '{ print $1 }')));
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
	                        echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?" > $OUTPIPE
	                        # exit 1 # I am learning that my random exits are bad news.
	                fi
	        fi
		unset existingbackups;
		DATE=$(date +%Y-%m-%d-%Hh%M)
	        BACKUP_FILENAME=$SERVER_PROPERTIES_WORLD-$DATE-full.tgz
	        tar -czhf $BACKUP_PATH/$BACKUP_FILENAME $COPY_OF_WORLD >/dev/null 2>&1
		unlink $BACKUP_FULL_LINK
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

# I know, starting a new thread to watch over and terminate an old thread is dumb.
# I am still looking for ways for the "cat" thread to maintain itself.
while true; do
        if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
                sleep 1;
        else
                kill -15 $CATPID >/dev/null 2>&1;
		rm $OUTPIPE;
		exit;
        fi
done &

# Pump STDIN into our input pipeline
# trap "echo \"Please don\'t.\n\"" SIGINT SIGTERM SIGHUP SIGABRT SIGKILL SIGQUIT SIGALRM; # A sad failed attempt to catch Control-C

while read input; do
#	if [ -d /proc/$JAVA_SUBSHELL_PID ]; then
		# The main issue with this logic is that this loop requires a newline after program termination
		# to check on the java subshell and realize it needs to exit.
		echo $input > $INPIPE;
#	else
#		exit 0;
#	fi
done

