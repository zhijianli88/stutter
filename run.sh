#!/bin/bash
# Main code from Mel Gorman's MMTests

[[ $MEMTOTAL_BYTES ]] || exit
[[ $TESTDISK_DIR ]] || exit
[[ $ITERATIONS ]] || exit
[[ $LOGDIR_RESULTS ]] || exit

STUTTER_MEMFAULT_SIZE=$((MEMTOTAL_BYTES*3/4&~1048575))
STUTTER_FILESIZE=$((MEMTOTAL_BYTES*2))
STUTTER_BLOCKSIZE=$((2*1048576))

# Figure out how to use the time cmd
TIME_CMD=`which time`
if [ "$TIME_CMD" = "" ]; then
	TIMEFORMAT="%2Uuser %2Ssystem %Relapsed %P%%CPU"
	TIME_CMD="time"
fi

# Calibrate the expected time to complete
echo "# Calibrating IO speeds"
$TIME_CMD -o $LOGDIR_RESULTS/calibrate.time \
	dd if=/dev/zero of=$TESTDISK_DIR/ddfile ibs=$STUTTER_BLOCKSIZE count=$((1024*1048576/STUTTER_BLOCKSIZE)) conv=fdatasync &> $LOGDIR_RESULTS/calibrate.log
rm "$TESTDISK_DIR/ddfile"

# Create source file
echo "# Creating source file: $TESTDISK_DIR/stutter-source-file"
dd if=/dev/zero of=$TESTDISK_DIR/stutter-source-file bs=$STUTTER_BLOCKSIZE count=$((STUTTER_FILESIZE/STUTTER_BLOCKSIZE)) conv=fdatasync &> $LOGDIR_RESULTS/create_source.log


# Dump all existing cache for full IO effect
echo "# Dropping caches, inodes and dentries"
sync
echo 3 > /proc/sys/vm/drop_caches

# Start the latency monitor
echo "# Starting mapping latency monitor"
./latency > $LOGDIR_RESULTS/mmap-latency.log &
LATENCY_PID=$!

function shutdown_pid()
{
	SHUTDOWN_PID=$1
	while [ "`ps h --pid $SHUTDOWN_PID`" != "" ]; do
		sleep 1
		ATTEMPT=$((ATTEMPT+1))
		if [ $ATTEMPT -gt 5 ]; then
			kill -9 $SHUTDOWN_PID 2>/dev/null
		fi
	done
}

RETRYING=5
for ITERATION in `seq 1 $ITERATIONS`; do
	RUNNING=-1
	while [ $RUNNING -ne 0 ]; do
		echo "# Starting memhog"
		./memhog $STUTTER_MEMFAULT_SIZE &
		MEMHOG_PID=$!

		sleep 10

		# Make sure it's running
		ps -p $MEMHOG_PID > /dev/null
		RUNNING=$?
		if [ $RUNNING -ne 0 ]; then
			if [ $RETRYING -eq 0 ]; then
				echo "# memhog can not suceess..."
				kill $LATENCY_PID
				exit 1
			fi
			sync
			echo "# memhog exited abnormally, retrying"
			RETRYING=$((RETRYING-1))
		fi
	done
	echo "# Starting cp $TESTDISK_DIR/stutter-source-file $TESTDISK_DIR/ddfile"
	echo "#!/bin/bash
cp $TESTDISK_DIR/stutter-source-file $TESTDISK_DIR/ddfile
sync" > cp-script.sh
	chmod u+x cp-script.sh
	$TIME_CMD -o $LOGDIR_RESULTS/time.$ITERATION \
		./cp-script.sh &> $LOGDIR_RESULTS/dd-$ITERATION.log
	rm cp-script.sh

	shutdown_pid $MEMHOG_PID
done

rm -f "$TESTDISK_DIR/stutter-source-file" "$TESTDISK_DIR/ddfile"
kill $LATENCY_PID

exit 0
