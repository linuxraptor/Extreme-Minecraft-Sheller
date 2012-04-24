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
# Place this file in the folder where minecraft world and server relies, preferably.
# Change WORLD, SERVER, and maybe WORLD_IN_RAM to the correct locations
#To see the console of the minecraft server type "screen -xRRA" in terminal

#NO TOUCHY, use the variable if the world is in the same directory as this script
directory_name="$( cd "$( dirname "$0" )" && pwd )"

#Path to your world folder
WORLD="$directory_name/world_storage"
WORLD_DIRNAME="`dirname $WORLD`"

#Path to your minecraft server
#SERVER="$directory_name/craftbukkit-0.0.1-SNAPSHOT.jar"
SERVER="$directory_name/minecraft_server.jar"

#You must know what your doing with your changing this path. Your on your own on this on.
WORLD_IN_RAM="/dev/shm/minecraft/World_in_RAM"

#VOLATILE is the path the World symlink is going to be located linked to the
#NOTE: Make sure your server.properties is pointing to the World_in_RAM
VOLATILE="$WORLD_DIRNAME/World_in_RAM"



###Don't Change Anything Below this###

echo 'Removing any leftover lockfiles...'
rm $WORLD/session.lock $WORLD_DIRNAME/server.log.lck > /dev/null

echo 'Removing old symlinks...'
# We're not using 'rm -r' in case World_in_RAM ends up being the actual world folder instead of a symlink, but not that likely.
rm $VOLATILE 2>&1 > /dev/null

#Clean anything World that was left on the RAM
echo 'Cleaning volatile memory...'
rm -rf $WORLD_IN_RAM 2>&1 > /dev/null

#Setup folder in RAM for the world to be loaded
echo "Building $WORLD_IN_RAM directory tree..."
mkdir -p $WORLD_IN_RAM

echo "Copying $WORLD backup to $WORLD_IN_RAM ..."
cp -aR $WORLD/* $WORLD_IN_RAM/

echo "Entering directory $WORLD_DIRNAME ..."
cd $WORLD_DIRNAME

echo "Linking $WORLD_IN_RAM to location as defined in server.properties, which should be `basename $VOLATILE`"
ln -s $WORLD_IN_RAM $VOLATILE 

echo "Starting minecraft world $WORLD..."
sleep 3
cd `dirname $0`
screen -dmS Minecraft `java -server -Xms2048M -Xmx2048M -Djava.net.preferIPv4Stack=true -jar $SERVER nogui`  && rsync -ravuP --delete --force "$WORLD_IN_RAM/" "$WORLD" && screen -p Minecraft -X stuff "$(printf "say RAM sync complete.\r")"
#Reniceing helps the soul, just like a bowl of chicken soup.
renice -n -10 -p `ps -e | grep java | awk '{ print $1 }'` 
