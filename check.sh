#!/bin/bash

# A little Qortal logger by Saku Mättö


# ONLY run this script in the Qortal installation directory which is
# assumed to be usernamehome/qortal. If this is not so, pls
# change below to correct dir before fireing up

# This script is meant to be run automatically every five minutes by cron and
# it will keep track of you minting and the height where you are.
# # m h  dom mon dow   command   // SAMPLE crontab entry on row below
# */5 * * * * /home/pi/qortal/check.sh QQZUGdXgSY5ggrfMfjxs2wBe74PYHJdaHC 3mKQtEM9q7iPpcqsD73xcBvN12u8fomzs1PDcqjZHWbU 2>&1
# ie run every 5 minutes file and give qortal ID and minting key as entries after file name, finally pass all output to empty

# It prints the values in a form like this into a file "FILE"
#  TIME   HEIGHT DIFF MINTED (SECS TEMP)
# 16:40   309251 0    4310M  (  1s 74.7'C)
# Time in 24H format
#         Present height your system reports for your chain
#                Height difference from last log
#                     How much you've minted
#                             (seconds it took this to run
#                                  Pi processor temp in Centigrade)

# Always at tallying time it will print the number minted and core version
# Pls set tally time to your liking (if midnight is not good for you)

# In a separate file it will log the status of your system "MINTFILE"
# This second file will help you determine if and why your Qortal is getting stuck

# Every hour on the hour print Qort status to file MONEYFILE

### Change history
## March 16, 2021 added core version logging $VERSION
## March 20 added logging of core version number
## March 25 added functionality to log processor temp if on a Pi
## March 29 added functionality to automatically orphan and to check core is online
## Also made constants of size to rotate and number blocks to orphan & tally time and minimum log rows before orphan

########################################
## Precheck that core running, if not quit
COREON=$(ps -ef | grep [jJ]ava)
if [[ ! $COREON == *qortal.jar* ]]; then
	exit 1
fi

########################################
### Constants
TOORPHAN=135
ORPHANREST=6
ROTATESIZE=100
TALLY="00:00"

### Prepare file names etc
STARTTIME=$SECONDS
TIME=$(date +"%H:%M")
DATE=$(date +"%d.%m.%Y")
DIR=$(eval echo "~$USER/qortal")
FILE=$DIR/my-qortal-log.txt
MINTFILE=$DIR/my-status-log.txt
MONEYFILE=$DIR/qortal.balance.txt

### Get core version
VERSION=$(curl -s -X  GET "http://127.0.0.1:12391/admin/info" | awk -F':' '{print $4}' | awk -F',' '{print $1}' | sed 's/"//g' | sed 's/qortal-//g')

### Get Qort minted status
PRECHECK=$(curl  -s -q http://127.0.0.1:12391/admin/status)
if [ $1 ]; then
	MYKEY=$1
	[ ! $MYKEY ] && read -n34 -p "Enter your Qortal key as first variable in the command if you do not wish to enter it here: " MYKEY && echo -e "\n"
	MONEY=$(curl -s -X  GET "http://127.0.0.1:12391/addresses/balance/$MYKEY" -H "accept: text/plain")
fi

if [ $2 ]; then
	MINTKEY=$2
fi




########################################
#Prepare log files only if they do NOT exist
[ ! -f $FILE ] && printf "#%5s %7s %-3s %11s (%3ss)\n" "TIME" "HEIGHT" "DIFF" "MINTED" "SEC TEMP" >> $FILE && echo "#V$DATE core version: $VERSION" >> $FILE
[ ! -f $MINTFILE ] && printf "#%9s %8s %5s %s\n" "DATE" "TIME" "MINTED" "CHECK STRING" >> $MINTFILE



########################################
### Functions
check () {
	CHECK=$(curl  -s -q http://127.0.0.1:12391/admin/status)
	# isSynchronizing":true
	if [[ $(echo $CHECK | awk -F',' '{print $2}' | awk -F':' '{print $2}') == "true" ]]; then
		return 1
	else
		return 0
	fi
}

rotate () {
  # Source: https://stackoverflow.com/a/32460799/3826136, with thanks
  # minimum file size to rotate in kbits:
  local KB="$1"
  # filename to rotate (full path)
  local F="$2"
#  local msize="$((MB*1024*1024))"
  local msize="$((KB*1024))"
  test -e "$F" || return 2

  local D="$(dirname "$F")"
  local E=${F##*.}
  local B="$(basename "$F" ."$E")"

  local s=

  local FF=$(ls -la "$F" | awk {'print $5'})
  if [ $FF -gt $msize ] ; then
    echo "#$DATE $TIME rotate msize=$msize file=$F" >> $F
     for i in 9 8 7 6 5 4 3 2 1 0; do 
       s="$D/$B-$i.$E"
       test -e "$s" && mv $s "$D/$B-$((i+1)).$E"
  # empty command is need to avoid exit iteration if test fails:
       :;
     done &&
     mv $F $D/$B-0.$E
  fi
  return $?
}

orphan() {
	# Check to see if height is stuck (ie not adding = 0 delta) and if it has been stuck for 5
	# consecutive checks, orphan TOORPHAN number of blocks
	# The command to orphan is curl -X POST "http://localhost:12391/admin/orphan" -H "accept: text/plain" -H "Content-Type: text/plain" -d "343114" # where you replace 343114 with the actual height you want to orphan to
	ORPHANLIMIT=$(tail -n$ORPHANREST $FILE | awk -F ' ' {'print $2'} | wc -l)
	LAST=$(tail -n$ORPHANREST $FILE | awk -F ' ' {'print $2'})
	FIVELAST=$(tail -n5 $FILE | awk -F ' ' {'print $2'})
	FIRST=$(echo $FIVELAST | awk -F ' ' {'print $1'})
	FIFTH=$(echo $FIVELAST | awk -F ' ' {'print $5'})
	
	# If we recently orphaned, then do nothing (limit ORPHANREST above)
	[[ "orphaning" == *"$LAST"* ]] && return 10
	# If we recently rotated log file, we need to wait for enough data so do not orphan
	[[ $ORPHANLIMIT -le $ORPHANREST ]] && return 11

	# If we need to orphan, after the orphan command returns we echo time, IF this time is immediate, then we know that the orphan returned FALSE and di not start at all
	if [ $FIFTH == $FIRST ]; then
		TARGET=$(($FIRST-$TOORPHAN))
		ORPHANTIME=$(date +"%H:%M")
		ORPHANEDTIME=$ORPHANTIME
		echo "# $ORPHANTIME orphaning to $TARGET" >> $FILE
		while [ ! $ORPHANTIME == $ORPHANEDTIME ]; do
			curl -X POST "http://localhost:12391/admin/orphan" -H "accept: text/plain" -H "Content-Type: text/plain" -d "$TARGET"
			$ORPHANEDTIME=$(date +"%H:%M")
			sleep 2
		done
		echo "# $ORPHANEDTIME orphaning to $TARGET" finished >> $FILE
	fi
# No need to corerestart after orphaning
}

mintstatus() {
	MINTED=$(curl -s -q "http://127.0.0.1:12391/addresses/$MYKEY" | awk -F ':' {'print $8'} | awk -F ',' {'print $1'})
	if   [ "$MINTED" -ge 1036800 ]; then L="L10"
	elif [ "$MINTED" -ge 864000 ]; then L="L9"
	elif [ "$MINTED" -ge 691200 ]; then L="L8"
	elif [ "$MINTED" -ge 518400 ]; then L="L7"
	elif [ "$MINTED" -ge 345600 ]; then L="L6"
	elif [ "$MINTED" -ge 244000 ]; then L="L5"
	elif [ "$MINTED" -ge 172800 ]; then L="L4"
	elif [ "$MINTED" -ge 129600 ]; then L="L3"
	elif [ "$MINTED" -ge 64800 ]; then L="L2"
	elif [ "$MINTED" -ge 7200 ]; then L="L1"
	else L="M"
	fi
}

gettemp() {
	ISPI=$(cat /proc/device-tree/model | awk '{print $1}')
	if [ $ISPI == "Raspberry" ]; then
		TEMP=$(/opt/vc/bin/vcgencmd measure_temp | sed 's/temp=//g')
		else
		TEMP="n/a"
	fi
}
# We actually do not use corerestart for anything, but it is here for future use
corerestart() {
	SHUTTIME=$(date +"%T")
	# Shutdown any existing session and wait 10s and kill java sessions
	echo "# Shut core $SHUTTIME" >> $FILE
	curl 127.0.0.1:12391/admin/stop && sleep 10 && killall -9 java
	# wait again
	sleep 10
	#done

	# Start new session by calling the start shell script
	RESTARTTIME=$(date +"%T")
	$DIR/start.sh && PID=$(cat $DIR/run.pid)
	echo "# Restart core $RESTARTTIME - $PID" >> $FILE

}

########################################
### Actual logic


# Rotate log files if need be (ie size > ROTATESIZE kB)
rotate $ROTATESIZE $FILE
rotate $ROTATESIZE $MINTFILE
rotate $ROTATESIZE $MONEYFILE

# while isSynchronizing":true sleep a while and retry, this can take even minutes
until check; do
	sleep 3
done

# if we have the mintkey then get minting status for user
[ $MINTKEY ] && mintstatus

# if on a Pi, might as well log the temp
gettemp

# get last logged height
STATUS=$(tail -n25 "$FILE" | grep -v "#" | grep -v "height" | awk '{print $2}' | tail -n1)

# get new height
HEIGHT=$(echo $CHECK | awk -F':' '{print $5}' | awk -F'}' '{print $1}')

# if we got the last logged height, calculate delta
[ $STATUS ] && DIFF=$((HEIGHT-STATUS))

# If tally time, print date and coins minted during previous 24h from last tally time, also print core version
if [ $TIME == $TALLY ]; then
	PREVMINTED=$(tail -n300 "$FILE" | grep "$TALLY" | awk '{print $4}' | awk -F'[ML]' '{print $1}')
	DELTA=$((MINTED-PREVMINTED))
	[ $MINTED ] && echo "##$DATE 24H minted: $DELTA" >> $FILE
	echo "#V$DATE core version: $VERSION" >> $FILE
fi

# Every hour on the hour print cash status to file MONEYFILE
if [[ $(echo "$TIME" | awk -F':' '{print $2}') == 00 ]]; then
	printf "%5s %8s %s\n" "$DATE" "$TIME" "$MONEY" >> $MONEYFILE
fi

# total time it took us to log everything
ENDTIME=$((SECONDS-STARTTIME))

#Log results
printf "%5s %8s %5sM %s\n" "$DATE" "$TIME" "$MINTED" "$PRECHECK" >> $MINTFILE
printf "%5s %8s %-3s %5s$L  (%3ss %s)\n" "$TIME" "$HEIGHT" "$DIFF" "$MINTED" "$ENDTIME" "$TEMP" >> $FILE

# Run orphaning and let process go to b/g so it doesn't hinder execution of this script on consecutive runs, if orphaning should actually start
orphan &