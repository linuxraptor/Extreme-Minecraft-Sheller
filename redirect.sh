#!/bin/bash

#SERVER_JAR=craftbukkit-0.0.1-SNAPSHOT.jar
SERVER_JAR=minecraft_server.jar
SERVER=$(pwd)/$SERVER_JAR

MCPID=$(pgrep -lf $SERVER | awk -F' ' '{print $1}')

#ls -al /proc/$MCPID/fd | grep $(pwd) | grep .log | awk -F' ' '{print $9}'

TAILPID=$(pwd)/tail-$(date --rfc-3339=ns | awk -F. '{print $2}').pid

(tail -f -n 200 /proc/$MCPID/fd/10
kill -15 $$
) &

# gotta look into possibility of this being 10 all the time
# i wanna use the grep above but i get .log and .log.lck
# there has to be a way to grep exclusively for .log (find maybe?)
# or use grep to specifically exclude results.


for f in $( ls -1 | grep .pipe )
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

