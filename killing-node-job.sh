#!/bin/bash

# Configurable parameters
MAX_Serial_CPU=35
MAX_Serial_CPU_SEC=1800
MAX_Mpi_CPU_SEC=900

LOG_FILE="/home/tmp/topcpumsgrecord"

# Define top CPU-consuming processes, excluding specified commands
top_serial_pids=$(ps -eo pid,ppid,uid,user,lstart,etime,etimes,cmd,%mem,%cpu --sort=-%cpu |
                  egrep -v "tar|gcc|mpicc|wget|git|zip|rsync|make|gmake|ssh|kamalph" |
                  head -n 6 | awk '{ print $1 }' | grep -v PID)

# Process each serial process
for pid in $top_serial_pids; do
    CPUusage=$(ps -q $pid -o %cpu= | awk '{print int($1)}')
    Elapsedtime=$(ps -q $pid -o etimes= | awk '{print int($1)}')
    Username=$(ps -q $pid -o user=)
    Command=$(ps -q $pid -o cmd=)
    Starttime=$(ps -q $pid -o lstart=)
    Usermail=$(ldapsearch -x -b "dc=nsm,dc=in" "(uid=$Username)" | awk '/^mail:/ { print $2 }')

    if [ "$CPUusage" -gt "$MAX_Serial_CPU" ] && [ "$Elapsedtime" -gt "$MAX_Serial_CPU_SEC" ]; then
        message="$Username used the login node: $(uname -n) at $Starttime for more than 30 mins for a serial process ($Command) \
                 which consumed more than $MAX_Serial_CPU% CPU. The process will be terminated. Repeat offenses will lead to account lock."

        # Send email notification
        echo "$message" | mailx -s "HPC Login Node Policy Violation - Excessive Resource Usage" "$Usermail"

        # Kill the process
        kill -15 "$pid"

        # Log the event
        echo "$(date) - Serial process violation by $Username - PID: $pid - $Command" >> "$LOG_FILE"
    fi
done

# Define top MPI processes
top_mpi_pids=$(ps -ef | egrep "mpirun|openmpi|mpiexec" | grep -v grep | awk '{ print $2 }')

for pid in $top_mpi_pids; do
    Elapsedtime=$(ps -q $pid -o etimes= | awk '{print int($1)}')
    Username=$(ps -q $pid -o user=)
    Command=$(ps -q $pid -o cmd=)
    Starttime=$(ps -q $pid -o lstart=)
    Usermail=$(ldapsearch -x -b "dc=nsm,dc=in" "(uid=$Username)" | awk '/^mail:/ { print $2 }')

    if [ "$Elapsedtime" -gt "$MAX_Mpi_CPU_SEC" ]; then
        message="$Username used the login node: $(uname -n) at $Starttime for more than 15 mins for an MPI process ($Command). \
                 The process will be terminated. Repeat offenses may lead to account lock."

        # Send email notification
        echo "$message" | mailx -s "HPC Login Node Policy Violation - Excessive Resource Usage" "$Usermail"

        # Kill the process
        kill -9 "$pid"

        # Log the event
        echo "$(date) - MPI process violation by $Username - PID: $pid - $Command" >> "$LOG_FILE"
    fi
done
