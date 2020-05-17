#!/bin/bash

###############################################################################
# Description:
#    * Reads CPU and GPU temperature sensors of Raspberry Pi
#    * Makes no attempt to check whether being run on a Raspberry Pi
###############################################################################

# CPU
cpu_temp_0=$(cat /sys/class/thermal/thermal_zone0/temp)
cpu_temp_1=$(($cpu_temp_0/1000))
cpu_temp_2=$(($cpu_temp_0/100))
cpu_temp_M=$(($cpu_temp_2 % $cpu_temp_1))
echo CPU temp"="$cpu_temp_1"."$cpu_temp_M"'C"

# GPU
echo GPU $(/opt/vc/bin/vcgencmd measure_temp)

