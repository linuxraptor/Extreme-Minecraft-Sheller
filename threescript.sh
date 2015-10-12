#!/bin/bash

# Potential limitations of this error handler:
#
# 1. If one script calls a function from another script, the line numbers may be incorrect.
#      This is because we offset the line number counter by 1 to make the stack trace a bit
#      easier to follow and more like the PHP stack trace.  We may simply have to remove
#      the offset in the future, requiring the line number to be written before the
#      function name in the stack trace if we want it to make sense.
#      (Right now we use "function(): relevant line that calls next function".)
#      (With a changed offset it will have to say:
#       "line that calls function: function().")
#
# 2. Right now I create the log from scratch upon a new error.  Obviously the script should
#      already have a log file, so this info should be appended instead.  This brings us to
#
# 3. The functions here have no way to manage script logging.
#      When should old logs be deleted?
#      Should logs that end in error have the same rules as logs that exited cleanly?
#      Should I have log rotation?  In-script or invoke syslog?
#      
# 4. Log levels will be necessary.  I assume this will require functions of its own.
#
# 5. If we want a yet more verbose mode, it would be neat if each line specified by the
#      BASH_LINENO array was printed out with the stack trace, to have an immediate in-depth
#      view of possible erroneous syntax.

function run_test() {
	trap '
		# The PIPESTATUS array is overwritten by any action.
		# It must be copied before anything else happens.
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
		# Ideally this should never be necessary, but if an error message was not given, then this array is probably also unestablished.
        	local EXIT_CODES="${PIPESTATUS[@]}";
		local RECEIVED_ERROR_MESSAGE="Unknown error. Exiting.";
	fi

        if [ ${EXIT_CODES[@]} -eq 0 ]; then
		# Again, hopefully this is never necessary, but we cannot assume correct error codes will be given.
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
		printf "\t $FRAME_COUNTER. ${BASH_SOURCE[$i]}: ${FUNCNAME[$i]}()";
		if [ ${BASH_LINENO[$i-1]} -ne ${BASH_LINENO[0]} ]; then
			printf ": line ${BASH_LINENO[$i-1]}";
		fi;

		if [ -n "${EXIT_CODES[$i-1]}" ]; then
			printf ": Exited with code ${EXIT_CODES[$i-1]}\n";
		else
			printf "\n";
		fi;
		((FRAME_COUNTER++));
	done);
	ERROR_STRING+=":\n\t   \"$RECEIVED_ERROR_MESSAGE\"\n";
	ERROR_STRING+="Exited with code $EXIT_CODE\n";
	ERROR_STRING+="$(date +%b\ %d\ %H:%M:%S)";

	printf "$ERROR_STRING\n" | tee $TMPFILE >&2;

        exit $EXIT_CODE;
}

function pause() {
        # Given a number of seconds, sleep while watching main PID.

        if [ -z "$1" ]; then
                die "Pause time not given.";
        fi;

        SECONDS_TO_SLEEP=$1;
        for (( i=0; i<$SECONDS_TO_SLEEP; i++ )); do
                sleep 1;
        done;

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
	run_test "rsync /does/not/exist /still/does/not/exist";
}

if [[ $@ == "rsync_test" ]]; then
	wrapper_function_one;
else
	echo "Next time...";
fi
