################################################################################
# Description:
#    * Originally written in 2012-11
#    * Decreases priority of Box Sync process from 'Normal' to 'BelowNormal'
#    * Intended to be executed by a Scheduled Task upon logon
################################################################################


# Set priority of Box Sync process to 'Below Normal'
Get-Process -Name "BoxSync" | foreach {$_.PriorityClass = "BelowNormal"}

