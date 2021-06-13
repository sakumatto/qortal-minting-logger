#!/bin/bash

STARTTIME=$SECONDS

# A little Qortal logger by Saku Mättö - should work on Linux / Raspberry / Mac out-of-the-box. No warranties, just as-is.


# ONLY run this script in the Qortal installation directory which is
# assumed to be usernamehome/qortal. If this is not so, pls
# change below to correct DIR before fireing up
# Also Pls remember to chmod + x check.sh to make it executable
# Finally please replace the start.sh in your Qortal home dir with the one here as this version will print the start time into the log.

# This script is meant to be run automatically every five minutes by cron and
# it will keep track of you minting and the height where you are.
# # m h  dom mon dow   command   // SAMPLE crontab entry on row below
# */5 * * * * /home/pi/qortal/check.sh QQZUGdXgSY5gg2fMfjxs2wBe74PYHJdaHC 3mKQtEM9q7iPpcqsD73xcBvN12u8fomzs1PDcqjZH2bU 2>&1
# ie run every 5 minutes file and give qortal ID and minting key as entries after file name, finally pass all output to null

# It prints the values in a form like this into a file "FILE"
#  TIME   HEIGHT DIFF MINTED (SECS TEMP)
# 16:40   309251 0    4310M  (  1s 74.7'C)
# Time in 24H format
#         Present height your system reports for your chain
#                Height difference from last log
#                     How much you've minted
#                             (seconds it took this to run, pls see directly below
#                                  Pi processor temp in Centigrade)

# isSynchronizing":true = how long it took to run. We wait in the check function for core to report that it is no longer syncing and when this happens, we get our levels. This gives us a little indication of how strained the processor is also, but mainly we wait because when we are syncing, we can't be minting. Normally all should run in 0-1 seconds but it can sometimes be in the thousands. If it takes more than 300 seconds, your log will show the timestamps in the wrong order if the next check runs immediately. This can happen even though we check every second. Obviously if you choose to cron other than 5 minutes this last time limit would change accordingly.

# Always at tallying time it will print the number minted and core version
# Pls set tally time to your liking (if midnight is not good for you)

# In a separate file it will log the status of your system "MINTFILE"
# This second file will help you determine if and why your Qortal is getting stuck

# Every hour on the hour print Qort status to file MONEYFILE

# If you want automatic orphaning when tally stops increasing, change below to something else than ""

### Change history
## March 16, 2021 added core version logging $VERSION
## March 20 added logging of core version number
## March 25 added functionality to log processor temp if on a Pi
## March 29 added functionality to automatically orphan and to check core is online
## Also made constants of size to rotate and number blocks to orphan & tally time and minimum log rows before orphan
## April 1 fixed orphaning. Added selector to turn off automatic orphaning.
## April 4 added setting to bug to separate bugfile, can be turned off or on
## All of April a lot of testing and changes of no use. Making automatic orphaning reliable is critical
## May 2 Corrected mintstatus() level changes, ie from L1 to L2 you need the 7200 plus 64800 etc as they are cumulative.
## May 27 when leveling up to height, print 9999 e102e instead of actual minted & level if said error occurs 
## and from then on "0M" (as it is still zero minted ). e102e indicates that your ID is not to be found on the blockchain.
## This will be the case when you build from genesis up to the point when your ID first is created.

### Prepare file names etc
TIME=$(date +"%H:%M")
DATE=$(date +"%d.%m.%Y")
DIR=$(eval echo "~$USER/qortal")
FILE=$DIR/my-qortal-log.txt
MINTFILE=$DIR/my-status-log.txt
MONEYFILE=$DIR/qortal.balance.txt
BUGFILE=$DIR/my-buglog-log.txt


### Constants
#### Get core version and number of connections we presently have
VERSION=$(curl -s -X  GET "http://127.0.0.1:12391/admin/info" | awk -F':' '{print $4}' | awk -F',' '{print $1}' | sed 's/"//g' | sed 's/qortal-//g')
CONNECTIONS=$(curl -s -X GET "http://127.0.0.1:12391/admin/status" | sed 's/"//g' | awk -F'numberOfConnections:' '{print $2}' | awk -F',' '{print $1}')
##### Other
[ ! -f /proc/device-tree/model ] && ISPI="" || ISPI=1 # Are we on a Pi? then make this 1, else ""
RUNCHECKER="off" #do you want to run the checker? "on" yes; "off" no
TOORPHAN="" # Number directly after equals sign, else make this an empty string "" if you wish NOT to orphan automatically, otherwise set the integer of how many blocks to orphan
ORPHANREST=6 # how many log entries to cool off after orphaning
ROTATESIZE=1000 #kB
TALLY="00:00" # This is the time when the tallying of the last 24 hrs is to be done, 00:00 is midnight
DEBUGGING="on" # Do we want to log a separate debugging log? Empty="" is logging off, or something="1" logging on

# Function to write debugging info to file (if DEBUGGING="on" above)
debug () {
	#Prepare buglog file only if it does NOT exist
	[ $DEBUGGING ] && [ ! -f $BUGFILE ] && echo -e "\t$TIME Created bugfile" >> $BUGFILE && echo "#V$DATE core version: $VERSION" >> $BUGFILE && echo "$TIME @ $SECONDS ($DATE)" >> $BUGFILE
	# Write buglog MSG
	[ $DEBUGGING ] && echo -e "\t$TIME $1" >> $BUGFILE
}

########################################
########################################
########################################
########################################
#Prepare other log files only if they do NOT exist
[ ! -f $FILE ] && printf "#%5s %7s %-3s %11s (%3ss)\n" "TIME" "HEIGHT" "DIFF" "MINTED" "SEC TEMP" >> $FILE && echo "#V$DATE core version: $VERSION" >> $FILE
[ ! -f $MINTFILE ] && printf "#%9s %8s %5s %s\n" "DATE" "TIME" "MINTED" "CHECK STRING" >> $MINTFILE
########################################



debug "## Precheck that core running"
########################################
## Precheck that core running (ref https://xit.fi/g8 )
COREON=$(ps -ef | grep [jJ]ava)
if [ ! "$COREON" == *"qortal.jar"* ]; then
	debug "Core pid not found"
	debug "$COREON"
else
	debug "Core found to be running"	
fi

debug "## Precheck that we even want to run checker"
########################################
## Precheck that we even want to run checker, if not quit
if [ $RUNCHECKER == "off" ]; then
	debug "RUNCHECKER == 'off' > exit"
#	exit 1
fi

debug "Start checker"
########################################
########################################


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

debug "Key is: $MYKEY"
debug "Mintkey is: $MINTKEY"


### Functions
check () {
	CHECK=$(curl  -s -q http://127.0.0.1:12391/admin/status)
	cons=$(curl -s -X GET "http://127.0.0.1:12391/admin/status" | sed 's/"//g' | awk -F'numberOfConnections:' '{print $2}' | awk -F',' '{print $1}')
	# isSynchronizing":true
	if [[ $(echo $CHECK | awk -F',' '{print $2}' | awk -F':' '{print $2}') == "true" ]]; then
		return 1
	else
		return 0
	fi
}

gettemp() {
	TEMP="n/a"
	[ $ISPI ] && TEMP=$(/opt/vc/bin/vcgencmd measure_temp | sed "s/'C//" | sed "s/temp=//")
	debug "## Temperature is $TEMP"	
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
    [ $DEBUGGING ] && echo "#$DATE $TIME rotate msize=$msize file=$F" >> $BUGFILE
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
	debug "Orphaning test: drop $TOORPHAN blocks?" 
	ORPHANLIMIT=$(tail -n6 $FILE | awk -F ' ' {'print $2'} | wc -l) && debug "Look at (orphanlimit: $ORPHANLIMIT) last rows"
	LASTROWS=$(tail -n6 $FILE | awk -F ' ' {'print $2'}) #&& [ $DEBUGGING ] && echo -e "\t$TIME\tLatest:$LASTROWS" >> $BUGFILE
	FIRST=$(echo $LASTROWS | awk -F ' ' {'print $1'})
	THIRD=$(echo $LASTROWS | awk -F ' ' {'print $3'})
	SIXTH=$(echo $LASTROWS | awk -F ' ' {'print $6'})
	
	# If we recently orphaned, then do nothing (limit ORPHANREST above)
	[[ $(tail -n6 $FILE) == *"orphaning"* ]] && echo 10 && return
	# If we recently rotated log file, we need to wait for enough data so do not orphan
	[[ $ORPHANLIMIT -lt $ORPHANREST ]] && echo 11  && return
	local MSG="Orphaning not required"

	# If we need to orphan, after the orphan command returns we echo time, IF this time is immediate, then we know that the orphan returned FALSE and did not start at all
	if [ $SIXTH == $FIRST ] && [ $SIXTH == $THIRD ]; then
		TARGET=$(($FIRST-$TOORPHAN))
		ORPHANTIME=$(date +"%H:%M")
		ORPHANEDTIME=$ORPHANTIME
		echo "#$ORPHANTIME orphaning - trying to $TARGET" >> $FILE
		[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANTIME trying orphaning to $TARGET" >> $BUGFILE

	# do actual orphaning test hereunder
	#todo, ponder if you want to push orphancall into bg https://stackoverflow.com/a/20018504/3826136
		while [[ ! $SUCCESS == "true" ]] && [[ ! $SUCCESS == *"error"* ]] && [[ $SECONDS -le 190 ]]; do
			SUCCESS=$(orphancall)
			$ORPHANEDTIME=$(date +"%H:%M")
			[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANEDTIME trying orphaning, sleep 60 $SUCCESS" >> $BUGFILE
			sleep 60
		done
			[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANEDTIME post sleep $SUCCESS after $SECONDS secs" >> $BUGFILE

		if   [ "$SUCCESS" == "true" ]; then local MSG="orphaning done"
			echo "#$ORPHANEDTIME $MSG" >> $FILE
			[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANEDTIME $MSG" >> $BUGFILE
			echo 0 && return
		elif [ "$SUCCESS" == "false" ]; then local MSG="orphaning NOT done"
			echo "#$ORPHANEDTIME $MSG" >> $FILE
			[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANEDTIME $MSG" >> $BUGFILE
			echo 12 && return
		else local MSG="orphaning rejected by core and/or timeout"
			echo "#$ORPHANEDTIME $MSG" >> $FILE
			[ $DEBUGGING ] && echo -e "\t$TIME\t$ORPHANEDTIME $MSG" >> $BUGFILE
			echo 13 && return
		fi		
	fi
	debug "$MSG"
	debug "echo 99 && return"
	echo 99 && return # Last rows not identical so no need to orphan

# No need to corerestart after orphaning in normal case, see hourly check though
}

orphancall () {
	RESULT=$(curl -s -X POST "http://localhost:12391/admin/orphan" -H "accept: text/plain" -H "Content-Type: text/plain" -d "$TARGET")
	echo $RESULT
}

mintstatus() {
#	MINTED=$(curl -s -q "http://127.0.0.1:12391/addresses/$MYKEY" | awk -F ':' {'print $8'} | awk -F ',' {'print $1'})
	READ=$(curl -s -q "http://127.0.0.1:12391/addresses/$MYKEY")
	if [[ ! $READ == *"error"* ]]; then
		MINTED=$(echo $READ | awk -F ':' {'print $8'} | awk -F ',' {'print $1'})
			if   [[ $MINTED -ge 4074400 ]]; then L="L10"
				elif [[ $MINTED -ge 3037600 ]]; then L="L9"
				elif [[ $MINTED -ge 2173600 ]]; then L="L8"
				elif [[ $MINTED -ge 1482400 ]]; then L="L7"
				elif [[ $MINTED -ge 964000 ]]; then L="L6"
				elif [[ $MINTED -ge 618400 ]]; then L="L5"
				elif [[ $MINTED -ge 374400 ]]; then L="L4"
				elif [[ $MINTED -ge 201600 ]]; then L="L3"
				elif [[ $MINTED -ge 72000 ]]; then L="L2"
				elif [[ $MINTED -ge 7200 ]]; then L="L1"
				else L="M"
			fi
		# The following two are the errors you get 
		# a) "error":102,"message":"invalid address" ie. you're not synced yet or 
		# b) "error":124,"message":"account address unknown" ie the key you gave is incorrect
		elif [[ ! $READ == *"102"* ]]; then
			MINTED=9999
			L=" e102e"
		elif [[ ! $READ == *"124"* ]]; then
			MINTED=9999
			L=" e124e"
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
	echo "# Restarted core $RESTARTTIME - pid $PID" >> $FILE

}

main() {
	########################################
	########################################
	########################################
	########################################
	### Actual logic in this main function



	########################################
	# Rotate log files if need be (ie size > ROTATESIZE kB)
	rotate $ROTATESIZE $FILE
	rotate $ROTATESIZE $MINTFILE
	rotate $ROTATESIZE $MONEYFILE
	rotate $ROTATESIZE $BUGFILE

	debug "starting while-test @ $SECONDS"


	consmin=$CONNECTIONS
	consmax=$CONNECTIONS

	########################################
	# while isSynchronizing":true sleep a while and retry, this can take even minutes
	
	until check; do

		# Update max if applicable
		if [[ $cons -gt $consmax ]]; then
			consmax=$cons
		fi

		# Update min if applicable
		if [[ $cons -lt $consmin ]]; then
			consmin=$cons
		fi

		sleep 1
		[ $DEBUGGING ] && [ $(($SECONDS%30)) -eq 0 ] && echo -e "\t$TIME while-test @ $SECONDS Cons: $consmin – $consmax" >> $BUGFILE
	done


	########################################
	# if we have the mintkey then get minting status for user
	[ $MINTKEY ] && mintstatus

	########################################
	# if on a Pi, might as well log the temp
	gettemp

	########################################
	# get last logged height
	STATUS=$(tail -n25 "$FILE" | grep -v "#" | grep -v "height" | awk '{print $2}' | tail -n1)

	# get new height
	HEIGHT=$(echo $CHECK | awk -F':' '{print $5}' | awk -F'}' '{print $1}')

	# if we got the last logged height, calculate delta
	[ $STATUS ] && DIFF=$((HEIGHT-STATUS))

	########################################
	# If tally time, print date and coins minted during previous 24h from last tally time, also print core version
	# Pls note that if there is less than 24H of data the tally has no reference to calculate delta on (fresh system or recently rotated log)
	if [ $TIME == $TALLY ]; then
		PREVMINTED=$(tail -n400 "$FILE" | grep "$TALLY" | tail -n1 |awk '{print $4}' | awk -F'[ML]' '{print $1}')
		DELTA=$((MINTED-PREVMINTED))
		[ $MINTED ] && echo "##$DATE 24H minted: $DELTA" >> $FILE
		echo "#V$DATE core version: $VERSION" >> $FILE
		[ $DEBUGGING ] && echo -e "\t$TIME## PREVMINTED: $PREVMINTED MINTED: $MINTED" >> $BUGFILE
		[ $DEBUGGING ] && echo "#V$DATE core version: $VERSION" >> $BUGFILE
	fi


	# Every hour on the hour
	########################################
	if [[ $(echo "$TIME" | awk -F':' '{print $2}') == 00 ]]; then
		# print cash status to file MONEYFILE
		printf "%5s %8s %s\n" "$DATE" "$TIME" "$MONEY" >> $MONEYFILE
		# If orphaning has not succeeded restart core
		if [[ $(tail -n25 $FILE | grep "orphaning - trying" | wc -l) -gt 1 ]]; then
			if [[ $(tail -n25 $FILE | grep "orphaning done" | wc -l) -gt 1 ]]; then
				if [[ $(tail -n25 $FILE | grep "Restart core" | wc -l) -lt 1 ]]; then
					echo "# $TIME Restart core by force ($(date +"%H:%M"))" >> $FILE
					corerestart
				fi
			fi
		fi
	fi

	########################################
	# Run orphaning only if $TOORPHAN is not "" empty string and let process go to b/g so it doesn't hinder execution of this script on consecutive runs, if orphaning should actually start
	[ $TOORPHAN ] && DIDWEORPHAN=$(orphan)

	if   [[ $DIDWEORPHAN -eq 0 ]]; then MSG="Orphaned successfully"
		elif [[ $DIDWEORPHAN -eq 10 ]]; then MSG="Too recently orphaned"
		elif [[ $DIDWEORPHAN -eq 11 ]]; then MSG="Too recent log rotation"
		elif [[ $DIDWEORPHAN -eq 12 ]]; then MSG="Couldn't orphan"
		elif [[ $DIDWEORPHAN -eq 13 ]]; then MSG="Error or timeout"
		elif [[ $DIDWEORPHAN -eq 99 ]]; then MSG="No need to orphan"
		else MSG="No orphaning as it is not turned on"
		fi



	########################################
	# total time it took us to log everything
	ENDTIME=$((SECONDS-STARTTIME))

	#Log results
	printf "%5s %8s %5sM %s\n" "$DATE" "$TIME" "$MINTED" "$PRECHECK" >> $MINTFILE
	printf "%5s %8s %-3s %5s$L  (%ss %s°C %scons)\n" "$TIME" "$HEIGHT" "$DIFF" "$MINTED" "$ENDTIME" "$TEMP" "$CONNECTIONS" >> $FILE



	debug "($MSG) pid-($OK)- end script @ $SECONDS seconds"
}


main "$@"; exit
# The end