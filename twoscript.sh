#!/bin/bash

#mkfifo -p testscript.pipe;

# Open new file descriptor.
#exec <>5;

tty=$(tty);

trap "echo -e \"\nControl-C detected.\"" SIGINT SIGTERM

while read input; do

	if [[ $input != "^C" ]]; then
		if [[ $input == "exit" || $input == "q" ]]; then 
			exit 0;
		elif [[ $input == debug ]]; then
			echo "hallo";
		fi 
	echo $input
	fi

done &

watch "ps -al" & > $tty;
