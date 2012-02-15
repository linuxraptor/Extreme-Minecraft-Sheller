#!/bin/bash
################################################################
# Management scripts are listed locally here to make them more #
# portable as a package. You may, however, specify the full    #
# path of these scripts if you wish them to be located in      #
# separate directories.                                        #
################################################################

STARTUP="mcRAM.sh"
SYNC="world-backup.sh"
BACKUP="remote-backup.sh"
BACKUP_DIR="/home/minecraft/automatic_backups/"
MAX_BACKUP_FILES=6
MAX_BACKUP_DIR_SIZE_MB=200

# For syncing
VOLATILE="/home/minecraft/World_in_RAM/"
PERMANENT="/home/minecraft/world_storage/"
SCREEN_NAME="Minecraft"
# For syncing

#Path to your world folder
WORLD="/home/minecraft/world_storage/"

WORLD_NAME="`basename $WORLD`"
WORLD_DIRNAME="`dirname $WORLD`"

# Backups
BACKUP_PATH=$WORLD_DIRNAME/automatic_backups
BACKUP_FULL_LINK=${BACKUP_PATH}/${WORLD_NAME}_full.tgz

#VOLATILE="$WORLD_DIRNAME/World_in_RAM"


SCRIPT_NAME="minecraft.sh"

#Remote host info
#rsync -ravu --delete --force $BACKUP_PATH root@192.168.1.136:$BACKUP_PATH
USERNAME="root";
LOCATION="192.168.1.136";

#######################################################
# Please don't mess with anything beyond this point.  #
#######################################################

MCPID=$(pgrep -f minecraft_server);
if [[ -n $MCPID ]]
	# If pgrep returns anything with string length greater than 0...
	then
		MCPORT=$( lsof -i 4 -a -p $MCPID | awk 'NR==2' | awk '{ print $(NF-1) }' |  awk -F':' '{ print $2 }' | awk -F'-' '{print $1}' );
		# Then set active minecraft internet port by parsing lsof output.
	else
	# If pgrep returns nothing...
		MCPORT="";
		# Minecraft internet port is unknown or nonexistent
fi

if [[ -n $MCPID ]]
        then
		DATE=$(date +'%Y-%m-%d %X')
		#DATE=$(date --rfc-3339=seconds)
                MINECRAFT_IS_RUNNING=1;
	        echo $DATE "[INFO] Minecraft server found with PID:" $MCPID "on port:" $MCPORT".";
		if [[ "$(pgrep -f $STARTUP)" ]]
		        then
		                echo $DATE "[INFO] Script -"$STARTUP"- running minecraft as expected. PID:" $(pgrep -f $STARTUP)".";
		        else
		                echo $DATE "[WARNING] Minecraft running, but not managed by" $STARTUP".";
		fi
	else
                MINECRAFT_IS_RUNNING=0;
		echo $DATE "[ERROR] No minecraft server found!";
fi

SYNCPID=$(pgrep -f $SYNC);
if [[ -n $SYNCPID ]]
	then
		SYNC_IS_RUNNING=1
	else
		SYNC_IS_RUNNING=0;
fi

BACKUPPID=$(pgrep -f $BACKUP);
if [[ -n $BACKUPPID ]]
        then
                BACKUP_IS_RUNNING=1;
        else
                BACKUP_IS_RUNNING=0;
fi

if [[ $MINECRAFT_IS_RUNNING == 1 ]]
	then
		DATE=$(date +'%Y-%m-%d %X')
		#DATE=$(date --rfc-3339=seconds)
		if [[ $SYNC_IS_RUNNING == 0 ]] && [[ $BACKUP_IS_RUNNING == 0 ]]
			then
				# Minecraft running with no current activity
				STARTUP_SAFE=0 SYNC_SAFE=1 BACKUP_SAFE=1 DELETION_SAFE=1;
				echo $DATE "[INFO] World files are free, safe to access files for sync or backup.";
			elif [[ $SYNC_IS_RUNNING == 1 ]] && [[ $BACKUP_IS_RUNNING == 0 ]]
				then
				# Sync is running, no backing up
				STARTUP_SAFE=0 SYNC_SAFE=1 BACKUP_SAFE=0 DELETION_SAFE=0;
				echo $DATE "[ERROR] Sync is running, PID:" $SYNCPID "backup unsafe!";
				# Wait for files to become available?
			elif [[ $SYNC_IS_RUNNING == 0 ]] && [[ $BACKUP_IS_RUNNING == 1 ]]
				then
				# Backup is running, no syncing
				STARTUP_SAFE=0 SYNC_SAFE=0 BACKUP_SAFE=1 DELETION_SAFE=0;
				echo $DATE "[ERROR] Backup is running, PID:" $BACKUPPID "sync unsafe!";
			else
				echo $DATE "[ERROR] SHIT. Sync and backup both running, beware of data corruption.";
		fi
	else
		echo $(date +'%Y-%m-%d %X') "[ERROR] Minecraft is NOT running. Startup safe.";
		STARTUP_SAFE=1 SYNC_SAFE=0 BACKUP_SAFE=0 DELETION_SAFE=0;
		# Backups run a RAM sync, don't wanna do that and destroy world files if minecraft isnt set up.
fi

function sync()
{
echo "Issuing save commands."
screen -p $SCREEN_NAME -X stuff "$(printf "save-on\r")" && sleep 1
screen -p $SCREEN_NAME -X stuff "$(printf "save-all\r")" && sleep 1
screen -p $SCREEN_NAME -X stuff "$(printf "save-off\r")" && sleep 1
rsync -ravuP --delete --force "$VOLATILE" "$PERMANENT"
screen -p $SCREEN_NAME -X stuff "$(printf "say RAM sync complete.\r")"
}

function smartsync()
{
if [[ -a /tmp/connected.status ]]
then
	if [[ CONNECTION==1 ]]
	then
		echo -e "Connection established with: $PLAYERS, sync recommended."
	else
		echo -e "No players currently connected."
	fi
        echo -e "There has been connection since the last sync."
        echo "Issuing save commands."
        screen -p $SCREEN_NAME -X stuff "$(printf "save-on\r")" && sleep 1
        screen -p $SCREEN_NAME -X stuff "$(printf "save-all\r")" && sleep 1
        screen -p $SCREEN_NAME -X stuff "$(printf "save-off\r")" && sleep 1
        rsync -ravuP --delete --force "$VOLATILE" "$PERMANENT"
        screen -p $SCREEN_NAME -X stuff "$(printf "say RAM sync complete.\r")"

	PLAYERS=$( netstat -an  inet | grep 25565 | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' );
	if [[ -n $PLAYERS ]]
	        then
	        CONNECTION==1 # Unnecessary because of connected.status file, but neat to see live output
	        echo -e "Connection still alive."
	else
	        CONNECTION==0
		rm /tmp/connected.status
	fi

else
        echo -e $DATE "[INFO] Sync status is current."
	screen -p $SCREEN_NAME -X stuff "$(printf "say Sync status current.\r")"
fi
}

function connectioncheck()
{

PLAYERS=$( netstat -an  inet | grep 25565 | grep ESTABLISHED |  awk '{print $5}' |  awk -F: '{print $1}' );

if [[ -n $PLAYERS ]]
        then
	if [[ -a /tmp/connected.status  ]]
	then
	        CONNECTION==1 # Unnecessary because of connected.status file, but neat to see live output
	else
	        touch /tmp/connected.status
		CONNECTION==1
		screen -p $SCREEN_NAME -X stuff "$(printf "say User $PLAYERS presence logged.\r")"
	fi
        echo -e "Connection established with: $PLAYERS, sync recommended."

else
	CONNECTION==0
        echo -e "Server empty, checking previous state."
        if [[ -a /tmp/connected.status ]]
                then
                echo -e "There has been connection since the last sync."
                # The connection.status file will remain there until the server does a smartsync. The smartsync will remove it.
        else
                echo -e "Sync status is current."
        fi
fi


}

function prepare_backup()
{
	SIZE_IN_BYTES=$(du -s $BACKUP_DIR | awk '{ print $1 }');
	MAX_BYTE_SIZE=$((1000 * $MAX_BACKUP_DIR_SIZE_MB));
	POTENTIAL_SIZE=$(($(du -s $BACKUP_DIR | awk '{ print $1 }') + $(du -s $VOLATILE | awk '{ print $1 }')));
	# I'll leave these in case anyone needs them in the future
#	BACKUP_DIR_SIZE=$(du -s $BACKUP_DIR | awk '{ print $1 }')
#	VOLATILE_SIZE=$(du -s $VOLATILE | awk '{ print $1 }')
#	POTENTIAL_SIZE=$(($BACKUP_DIR_SIZE + $VOLATILE_SIZE))
#	echo $POTENTIAL_SIZE $MAX_BYTE_SIZE

	if [[ $POTENTIAL_SIZE > $MAX_BYTE_SIZE ]]
        then
                echo "Backup directory above capacity:" $POTENTIAL_SIZE"KB >" $MAX_BYTE_SIZE"KB. Cleaning.";
		# Some neat working code that will express percent of overinflation if you have the "bc" (bash calculator) program.
#                QUOTIENT=$(echo $POTENTIAL_SIZE / $MAX_BYTE_SIZE|bc -l);
#                PERCENT=$(echo "100 * (1 - ( 1 / $QUOTIENT ))"|bc -l);
#                echo $PERCENT "percent too large. Cleaning.";
        else
                echo "Backup directory will accomodate pending backup." $POTENTIAL_SIZE"KB <" $MAX_BYTE_SIZE"KB.";
	fi

	declare -a fullpathnewfilecontent

	# WANNA KNOW SOME STUPIDNESS??
	# Bash handles arrays very strangely. If you try to shift all objects in an array
	# to make up for a removed object, you canot declare that array[i]=array[i+1] like
	# in C. You actually have to reset the entire array like I have done below.
	# ALSO, if you try to create a new array that include objects in an existing array,
	# will will put ALL of the existing array into one of the new array's objects
	# (like a huge fucking string, space delimited) and leave the rest of the new
	# array's objects empty. It seems like the only way to handle this is how it is
	# done below. The for loop below keeps the "find" list from becoming one gigantic object
	# because these following commands are syntactically correct but make one large objects
	# instead of one smaller one:
#       fullpathnewfilecontent=$(echo $(find $BACKUP_DIR -size +1M | sort -g))
#       newfilecontent=$(echo $(find $BACKUP_DIR -size +1M -printf "%f \n" | sort -g))
#       newfilecontent=($(find $BACKUP_DIR -size +1M -printf "%f \n" | sort -g))
	# (so this will actually spilit into separate objects) and the arraay=("${array[@]}") bullshit
	# below makes a new array every time an object is deleted because individual objects cannot
	# be edited continuously programmatically.

	for f in $(echo $(find $BACKUP_DIR -size +1M | sort -g))
	do
		fullpathnewfilecontent=( "${fullpathnewfilecontent[@]}" "$f" );
	done

	# For debugging
#	size=${#fullpathnewfilecontent[@]};

	while [[ $POTENTIAL_SIZE -gt $MAX_BYTE_SIZE && -n ${fullpathnewfilecontent[0]} ]]
	do
                echo  "Cleaning up" ${fullpathnewfilecontent[0]};
                rm ${fullpathnewfilecontent[0]};
                unset fullpathnewfilecontent[0];
                fullpathnewfilecontent=( "${fullpathnewfilecontent[@]}" );
		POTENTIAL_SIZE=$(($(du -s $BACKUP_DIR | awk '{ print $1 }') + $(du -s $VOLATILE | awk '{ print $1 }')));
		# For debugging
#		echo "Potential size" $POTENTIAL_SIZE
#		echo "Maximum size" $MAX_BYTE_SIZE
	done
}

function backup()
{
	if [[ ! -d $BACKUP_PATH  ]]; then
	        #If not then make the backup directory
	        if ! mkdir -p $BACKUP_PATH; then
	                echo "Backup path $BACKUP_PATH does not exist and I could not create the directory! Permissions maybe?"
	                rm $BACKUP_PATH/$WORLD_NAME.lock
	                exit 1 #FAIL :(
	        fi
	fi

#	cd $BACKUP_PATH

	echo "Beginning backup."

	DATE=$(date +%Y-%m-%d-%Hh%M)

	BACKUP_FILENAME=$WORLD_NAME-$DATE-full.tgz

#	pushd $WORLD_DIRNAME
	echo -e "tar -czhf " $BACKUP_PATH/$BACKUP_FILENAME " " $VOLATILE
	tar -czhf $BACKUP_PATH/$BACKUP_FILENAME $VOLATILE

#	popd

	rm -f $BACKUP_FULL_LINK
	ln -s $BACKUP_FILENAME $BACKUP_FULL_LINK

	echo "Backup process is over."
	echo "Syncing backup to external server."

	rsync -ravu --delete --force $BACKUP_PATH root@192.168.1.136:$BACKUP_PATH
	screen -p $SCREEN_NAME -X stuff "$(printf "say -Remote backup synchronization complete.-\r")"
}

if [[ $# -gt 0 ]]
	then
	# Here, I'm adding the user-accessable functions. I dont want to add the "external"
	# functions, because only the internals of the script really should call them.
		case "$1" in
                        ##############
                        "prepare_backup")
                                prepare_backup;
                                ;;
                        ##############
                        "backup")
                                prepare_backup && backup;
                                ;;
			##############
                        "sync")
                                sync;
                                ;;
                        ##############
                        "smartsync")
                                smartsync;
#                                connectioncheck && smartsync; # This isn't necessary because the script already calls it when searching for "CONNECTED" variable!
                                ;;
                        ##############
                        "connectioncheck")
                                connectioncheck;
                                ;;
                        ##############
			*)
				echo "Poopy head"
				;;
		esac
fi

# 4. Recursive function for sync and  backup. If safe == 1, execute prog. else, sleep
#    sleep a few seconds and re-call the safety check.
#    If there is a sanity check before every program, we won''t run into many issues.
#
# 6. atoi is a neat cpluspluc function that turns strings into integers. use sprintf instead
#
# 7. Add while loop to startup script such as --while [[ ! -z $MCPID ]]; then; exec $SYNC; sleep 3600;--
#    I can replace --$SYNC-- in the upper loop with --$BACKUP-- to handle both jobs.
#
#10. Now not only could i pgrep the new sync commands, but DONT FORGET the $SYNC variable. In our while
#    loop, we'll call --exec $SYNC--, assuming SYNC is set recursively to --minecraft.sh sync--.
#
#12. Logging?
#
#13. Use --check-- function to include the first three statements.
#
#14. Maybe run a PID check to see if there is more than one PID for minecraft.sh on initial run or java.

