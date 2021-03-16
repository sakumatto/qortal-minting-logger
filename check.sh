#!/bin/bash

# A little Qortal logger by Saku Mättö


# ONLY run this script in the Qortal installation directory which is
# assumed to be usernamehome/qortal. If this is not so, pls
# change line 33 below to correct dir before fireing up

# This script is meant to be run automatically say every five minutes and
# it will keep track of you minting and the height where you are.

# It prints the values in a form like this into a file "FILE"
#  TIME   HEIGHT DIFF MINTED (SECS)
# 16:40   309251 0    4310M  (  0S)
# Time in 24H format
#         Present height your system reports for your chain
#                Height difference from last log
#                     How much you've minted
#                             (seconds it took this to run)

# Always at midnight it will print the date DD.MM.YY

# In a separate file it will log the status of your system "MINTFILE"
# This second file will help you determine if and when your Qortal is getting stuck


### Prepare file names etc
STARTTIME=$SECONDS
TIME=$(date +"%H:%M")
DATE=$(date +"%d.%m.%Y")
DIR=$(eval echo "~$USER/qortal")
FILE=$DIR/my-qortal-log.txt
MINTFILE=$DIR/my-status-log.txt
MONEYFILE=$DIR/qortal.balance.txt

PRECHECK=$(curl  -s -q http://127.0.0.1:12391/admin/status)
[ $1 ] && MYKEY=$1
[ ! $MYKEY ] && read -n34 -p "Enter your Qortal key in the command if you do not wish to enter it here: " MYKEY && echo -e "\n"

if [ $2 ]; then
	MINTKEY=$2
	MONEY=$(curl -s -X  GET "http://127.0.0.1:12391/addresses/balance/$MINTKEY" -H "accept: text/plain")
fi

#Prepare log files only if they do NOT exist
[ ! -f $FILE ] && printf "#%5s %7s %-3s %6s (%3ss)\n" "TIME" "HEIGHT" "DIFF" "MINTED" "SEC" >> $FILE
[ ! -f $MINTFILE ] && printf "#%9s %8s %5s %s\n" "DATE" "TIME" "MINTED" "CHECK STRING" >> $MINTFILE


### Functions
check () {
	# isSynchronizing":true
	if [[ $(echo $(curl  -s -q http://127.0.0.1:12391/admin/status) | awk -F',' '{print $2}' | awk -F':' '{print $2}') == "true" ]]; then
		return 1
	fi
		CHECK=$(curl  -s -q http://127.0.0.1:12391/admin/status)
	return 0
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
     for i in 9 8 7 6 5 4 3 2 1 0; do 
       s="$D/$B-$i.$E"
       test -e "$s" && mv $s "$D/$B-$((i+1)).$E"
  # empty command is need to avoid exit iteration if test fails:
       :;
     done &&
     mv $F $D/$B-0.$E
     echo "#$DATE $TIME rotate msize=$msize file=$F" >> $F
  fi
  return $?
}


### Actual logic
# while isSynchronizing":true sleep a while and retry
until check; do
	sleep 2.5
done

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


STATUS=$(tail -n25 "$FILE" | grep -v "#" | grep -v "height" | awk '{print $2}' | tail -n1)
HEIGHT=$(echo $CHECK | awk -F':' '{print $5}' | awk -F'}' '{print $1}')
[ $STATUS ] && DIFF=$((HEIGHT-STATUS))
ENDTIME=$((SECONDS-STARTTIME))

# If midnight, print date and coins minted during previous day
if [ $TIME == '00:00' ]; then
	PREVMINTED=$(tail -n290 "$FILE" | grep  -A1 "##" | grep -v "#" | awk '{print $4}' | awk -F'[ML]' '{print $1}')
	TOTAL=$((MINTED-PREVMINTED))
	echo "##$DATE 24H minted: $TOTAL" >> $FILE
fi

#Log results
printf "%5s %8s %5sM %s\n" "$DATE" "$TIME" "$MINTED" "$PRECHECK" >> $MINTFILE
printf "%5s %8s %-3s %5s$L  (%3ss)\n" "$TIME" "$HEIGHT" "$DIFF" "$MINTED" "$ENDTIME" >> $FILE
printf "%5s %8s %s\n" "$DATE" "$TIME" "$MONEY" >> $MONEYTFILE
# Rotate log files if need be (ie size > 100 kB)
rotate 100 $FILE
rotate 100 $MINTFILE
