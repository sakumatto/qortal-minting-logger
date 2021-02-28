# Qortal minting logger
 Log your minting activity by adding this script to crontab
- Works on Mac and Linux / Pi

# Why Qortal minting logger
As a Qortal minter you want to keep tabs on the height of the blockchain and the number you have minted. This bash script helps you do exactly that. The recommendation is to run it through cron, but you can equally run the script every now and then from the command line. The script writes its findings into two different log files and it rotates those files automatically.

#Place the script in your Qortal directory
The script is meant to reside in your home/qortal directory, that is a directory named qortal that resides under your home:
```~$USER/qortal
	/my-qortal-log.txt
	/my-status-log.txt
```
It will write into the same directory.

You can replace your start.sh with the one here. The changes in this start.sh script will write every start / restart into the log file along with the pid of Qortal.

When you run the script, you have two ways of entering you Qortal key:
1) By entering it as a parameter after the command
1) The script will ask for it if not given on call

# Run the script automatically with cron
You can place an automated way to run the script by entering it into your user crontab

```crontab -e
```

Place these commands into it

```*/5 * * * * /Users/saku/qortal/check.sh Qb123412345123412341234e74PYHJdaHC 2>&1
```
In the above the Qb... is your Qortal key