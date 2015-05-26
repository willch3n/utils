################################################################################
# Description:
#    * Originally written in 2012-12
#    * Increases priority of DisplayLink process from 'Normal' to 'AboveNormal'
#    * Intended to be executed by a Scheduled Task upon logon
################################################################################


# Set priority of DisplayLink process to 'Above Normal'
Get-Process -Name "DisplayLinkManager" | foreach {$_.PriorityClass = "AboveNormal"}

