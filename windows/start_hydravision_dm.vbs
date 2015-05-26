''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Originally written on 2010-05-05
'    * Starts HydraVision Desktop Manager
'    * Intended to be executed as a logon script
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Variables and constants
Dim objShell, objWMIService
Dim strSession, strProcessName, colListOfProcesses
Set objShell = WScript.CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
strProcessName = "HydraDM.exe"


' Get session name
strSession = objShell.ExpandEnvironmentStrings("%SESSIONNAME%")

' If console session, start 'HydraDM.exe' if it is not already running
Set colListOfProcesses = objWMIService.ExecQuery("Select * from Win32_Process Where Name ='" & strProcessName & "'")
If strSession = "Console" and colListOfProcesses.count = 0 Then
   objShell.Exec("C:\Program Files (x86)\ATI Technologies\HydraVision\HydraDM.exe")
End If

