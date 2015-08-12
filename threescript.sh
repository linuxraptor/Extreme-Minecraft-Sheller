#!/bin/bash

function run() {
	
	trap '
	EXIT_CODES="${PIPESTATUS[@]}";

	if [ ${EXIT_CODES[@]} -eq 0 ]; then
		local EXIT_CODE=1;
	else
		local EXIT_CODE="${EXIT_CODES[@]}";
	fi

	printf "Stack trace:\n";

	INCREASING_COUNTER="1";

	ERROR_STRING=$(for (( i=(${#FUNCNAME[@]} - 1); i>0; i-- )); do
		printf "\t $INCREASING_COUNTER. ${BASH_SOURCE[$i]}: ${FUNCNAME[$i]}(): line ${BASH_LINENO[$i-1]}: Exited with code ${EXIT_CODES[$i-1]}\n";
		INCREASING_COUNTER+=1;
	done);
	ERROR_STRING+=$ERROR_MESSAGE;

	printf "$ERROR_STRING\n";

        exit $EXIT_CODE;' ERR;
	COMMAND_OUTPUT=$("$@");
	printf "$COMMAND_OUTPUT\n";
}

function run_test() {
	trap '
		# The PIPESTATUS array is overwritten by any action.
		# It must be copied before anything else happens.
		# These variables should be global so that the die() function has access to them.
		EXIT_CODES="${PIPESTATUS[@]}";
		ERRONEOUS_COMMAND="$1";
		die "Uh-oh!";
	' ERR;

	# Making this variable local erases all error data when leaving this function.
	# Needs to stay global.
	COMMAND_OUTPUT=$("$@");
	printf "$COMMAND_OUTPUT\n";
}

function die() {
	# This stack trace was inspired by the PHP stack trace.	

	if [ -n "$1" ]; then
		local ERROR_MESSAGE="$1";
	else
		# Ideally this should never be necessary, but if an error message was not given, then this array is probably also unestablished.
        	local EXIT_CODES="${PIPESTATUS[@]}";
		local ERROR_MESSAGE="Unknown error. Exiting.";
	fi

        if [ ${EXIT_CODES[@]} -eq 0 ]; then
                local EXIT_CODE=1;
        else
                local EXIT_CODE="${EXIT_CODES[@]}";
        fi

	FRAME_COUNTER=0;
	# Do not increment frame counter until we are actually ascending frames.
	ERROR_STRING="Stack trace:\n";
	ERROR_STRING+="\t $FRAME_COUNTER. Working directory: $(pwd)\n";
	ERROR_STRING+="\t $FRAME_COUNTER. Script: $(readlink -fn $0)\n";
	ERROR_STRING+="\t $FRAME_COUNTER. Attempted command: \"$ERRONEOUS_COMMAND\"\n";
	((FRAME_COUNTER++));

	ERROR_STRING+=$(for (( i=(${#FUNCNAME[@]} - 1); i>0; i-- )); do
		printf "\t $FRAME_COUNTER. ${BASH_SOURCE[$i]}: ${FUNCNAME[$i]}(): line ${BASH_LINENO[$i-1]}";
		if [ -n "${EXIT_CODES[$i-1]}" ]; then
			printf ": Exit code ${EXIT_CODES[$i-1]}\n";
		else
			printf "\n";
		fi
		((FRAME_COUNTER++));
	done);
	ERROR_STRING+=": $ERROR_MESSAGE\n";
	ERROR_STRING+="Exited with code $EXIT_CODE";

	printf "$ERROR_STRING\n" >&2;

        exit $EXIT_CODE;
}

# This is a second wrapper function to test depth of error reporting.
function test_die() {
	die "This is a test error message.";
}
function test_die_silent() {
	die;
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

function broken_pause_wrapper() {
	pause;
}

function run_command() {
	COMMAND_OUTPUT=$("$@");
	trap "echo \"$BASH_COMMAND exited with error code $!.\nOutput:\n$COMMAND_OUTPUT\"" 1 2 3 6 9 14 15 ERR;

}

function err_report() {
	echo "Error on line $1"
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

if [[ $@ == "die" ]]; then
	test_die;
elif [[ $@ == "die_silent" ]]; then
	test_die_silent;
elif [[ $@ == "ls" ]]; then
	ls | grep nothing;

	
	for EXIT_CODE in ${PIPESTATUS[*]}; do
		printf ", $EXIT_CODE";
	done
	printf "\n";
elif [[ $@ == "pause" ]]; then
	broken_pause_wrapper;
elif [[ $@ == "rsync_unhandled_error" ]]; then
	rsync /does/not/exist /still/does/not/exist
elif [[ $@ == "rsync_handled_error" ]]; then
	run "rsync /does/not/exist /still/does/not/exist";
elif [[ $@ == "rsync_test" ]]; then
	wrapper_function_one;
elif [[ $@ == "report" ]]; then
	echo hello | grep foo;
	trap 'err_report $LINENO' ERR;
else
	echo "Next time...";
fi
