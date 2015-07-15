#!/bin/bash

#SERVER_JAR=craftbukkit-0.0.1-SNAPSHOT.jar
SERVER_JAR=minecraft_server.jar
SERVER=$(pwd)/$SERVER_JAR

MCPID=$(pgrep -f $SERVER)

#ls -al /proc/$MCPID/fd | grep $(pwd) | grep .log | awk -F' ' '{print $9}'

# here is something that works:
# echo "/help" | tee -a world-764620586-05\:00.pipe 2>&1 > /proc/4487/fd/1
# echo "/help" | tee -a [NAMED PIPE OF OPEN SESSION] 2>&1 > [FILE DESCRIPTOR OF PTY OR PTY ITSELF]

# while read input; do echo $input | tee -a ../minecraft-07-11-2015/world-764620586-05\:00.pipe 2>&1 > /proc/4487/fd/1; done

TAILPID=$(pwd)/tail-$(date --rfc-3339=ns | awk -F. '{print $2}').pid

MCPTY=$(readlink /proc/$MCPID/fd/* | grep -m 1 --color=never /dev/pts/)

#(tail -f $MCPTY
#kill -15 $$
#) &



# gotta look into possibility of this being 10 all the time
# i wanna use the grep above but i get .log and .log.lck
# there has to be a way to grep exclusively for .log (find maybe?)
# or use grep to specifically exclude results.


for f in $( ls -1 --color=never *.pipe )
do
	if [[ -n $(pgrep -f $f) ]]
	then
		PIPE=$f
	fi
done

while read input; do
	echo $input > $PIPE
done


# maybe add something to remove abondoned pipes?
# pgrep method is another good way of removing abondoned pid.status files.
# consider named pid solution?? nahhhhh not unique enough, would need to add
# data parameter and that ruins the uniqueness of the original pid number.

