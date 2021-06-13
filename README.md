# Qortal minting logger
 Log your minting activity by adding this script to crontab
- Works on Mac and Linux / Pi
- If your Qortal core is not running on this same machine, the script will not run.

This is provided as-is, no warranties.

# Why Qortal minting logger
As a Qortal minter you want to keep tabs on the height of the blockchain and the number you have minted. This bash script helps you do exactly that. The recommendation is to run it through cron with five minutes intervals. The script writes its findings into three different log files and it rotates those files automatically.

#Place the script in your Qortal directory
The script is meant to reside in your home/qortal directory, that is: a directory named qortal that resides under your home:
```
	~$USER/qortal
	/check.sh
	/my-qortal-log.txt
	/my-status-log.txt
	/qortal.balance.txt
```
It will write into the same directory.

You should replace your start.sh with the one herein. The changes in this start.sh script will write every start into the log file along with the pid of Qortal.


When you run the script, you have two ways of entering you Qortal key:
1) By entering it as a parameter after the command
1) The script will ask for it if not given on call
1) The optional minting key is needed for full benefits

_Strong recommendation_ is to give key(s) on call o get full benefit of script

# Therefore run the script automatically with cron
You can place an automated way to run the script by entering it into your user crontab

```
	crontab -e
```

Place this line/command into it your crontab (replacing the path with your actual path)

```
	*/5 * * * * /Users/macos/qortal/check.sh Qb123412345123412341234e74PYHJdaHC QM123412345123412341234e74PYHJdaHC 2>&1
```

In the above the Qb... is your Qortal key QM... is your Minting key

# A little Qortal logger by Saku Mättö

## Note
 ONLY run this script in the Qortal installation directory which is
 assumed to be usernamehome/qortal. If this is not so, pls
 change below to correct dir before fireing up

 This script is meant to be run automatically every five minutes by cron and
 it will keep track of you minting and the height where you are.
 // m h  dom mon dow   command   // SAMPLE crontab entry on row below
```
 */5 * * * * /home/pi/qortal/check.sh QQZUGdXgSY5ggrfMfjxs2wBe74PYHJdaHC 3mKQtEM9q7iPpcqsD73xcBvN12u8fomzs1PDcqjZHWbU 2>&1
```
 ie run every 5 minutes file and give qortal ID and minting key as entries after file name, finally pass all output to empty

## Shebang
Pls change the first row #!/bin/bash if your shell is different from mine

## How it logs
 It prints the values in a form like this into a file "FILE"
  TIME   HEIGHT DIFF MINTED (SECS TEMP)
 16:40   309251 0    4310M  (  1s 74.7'C)
 Time in 24H format
         Present height your system reports for your chain
                Height difference from last log
                     How much you've minted
                             (seconds it took this to run
                                  Pi processor temp in Centigrade)

 Always at tallying time it will print the number minted and core version
 Pls set tally time to your liking (if midnight is not good for you)

 In a separate file it will log the status of your system "MINTFILE"
 This second file will help you determine if and why your Qortal is getting stuck

 Every hour on the hour print Qort status to file MONEYFILE

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