#!/bin/bash

function run_or_die() {
	trap '
		# The PIPESTATUS array is overwritten by any action. It must be copied before anything else happens.
		EXIT_CODES="${PIPESTATUS[@]}";
		ERRONEOUS_COMMAND="$1";
		die "$(cat $TMPFILE)";
	' ERR;

	TMPFILE=/tmp/$0-error.log

	COMMAND_OUTPUT=$("$@" 2>$TMPFILE);
	printf "$COMMAND_OUTPUT\n";
	rm "$TMPFILE";
}

function die() {
	# This stack trace was inspired by the PHP stack trace.	

	if [ -n "$1" ]; then
		local RECEIVED_ERROR_MESSAGE="$1";
	else
		# Ideally this should never be necessary, but if an error message was not given, then this array is probably also unestablished. It is unlikely we will catch any exit codes at this point, but it is worth a try.
        	local EXIT_CODES="${PIPESTATUS[@]}";
		local RECEIVED_ERROR_MESSAGE="Unknown error. Exiting.";
	fi

        if [ ${EXIT_CODES[@]} -eq 0 ]; then
                local EXIT_CODE=1;
        else
                local EXIT_CODE="${EXIT_CODES[@]}";
        fi

	FRAME_COUNTER=1;

	ERROR_STRING="Working directory: $(pwd)\n";
	ERROR_STRING+="Script: $(readlink -fn $0)\n";
	ERROR_STRING+="Attempted command: \"$ERRONEOUS_COMMAND\"\n";
	ERROR_STRING+="Stack trace:\n";
	ERROR_STRING+=$(for (( i=(${#FUNCNAME[@]} - 1); i>0; i-- )); do
		printf "\t $FRAME_COUNTER. ${BASH_SOURCE[$i]}: ${FUNCNAME[$i]}(): line ${BASH_LINENO[$i-1]}";
		if [ -n "${EXIT_CODES[$i-1]}" ]; then
			printf ": Exit code ${EXIT_CODES[$i-1]}\n";
		else
			printf "\n";
		fi
		((FRAME_COUNTER++));
	done);
	ERROR_STRING+=":\n\t    $RECEIVED_ERROR_MESSAGE\n";
	ERROR_STRING+="Exited with code $EXIT_CODE\n";
	ERROR_STRING+="$(date +%b\ %d\ %H:%M:%S)";

	printf "$ERROR_STRING\n" | tee $TMPFILE >&2;

        exit $EXIT_CODE;
}

function wrapper_function_one() {
	wrapper_function_two;
}

function wrapper_function_two() {
	wrapper_function_three;
}

function wrapper_function_three() {
	wrapper_function_four;
}

function wrapper_function_four() {
	run_or_die "rsync /does/not/exist /still/does/not/exist";
}

if [[ $@ == "ps" ]]; then
	run_or_die ps;
elif [[ $@ == "ls" ]]; then
	run_or_die ls;
elif [[ $@ == "rsync_unhandled_error" ]]; then
	rsync /does/not/exist /still/does/not/exist;
elif [[ $@ == "rsync_handled_error" ]]; then
	run_or_die "rsync /does/not/exist /still/does/not/exist";
elif [[ $@ == "rsync_test" ]]; then
	wrapper_function_one;
else
	echo "Next time...";
fi
