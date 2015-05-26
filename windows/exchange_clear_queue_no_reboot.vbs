''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Originally written on 2010-02-12
'    * Clears Exchange mail queue without rebooting
'       * Stops Microsoft Exchange Transport service
'       * Renames "Queue" folder to "Queue.bak"
'    * Intended to be executed manually
'       * Depends on user to restart Microsoft Exchange Transport service or reboot server
'    * Used to work around bug that causes already-sent mail to be sent out again upon reboot
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Pragmas
On Error Resume Next

' Variables and constants
Dim objFSO, objShell, dataFolder, queueFolder, queueFolderToDelete, objWMIService
Dim strServiceName, colListOfServices, objService, strServiceState
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = WScript.CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
Set dataFolder = objFSO.GetFolder("C:\Program Files\Microsoft\Exchange Server\V14\TransportRoles\data")
strServiceName = "MSExchangeTransport"


' Report script start
WScript.Echo("Clearing Exchange mail queue.")

' Check existence of "Queue" folder
If Not objFSO.FolderExists(dataFolder & "\Queue") Then
   WScript.Echo(dataFolder & "\Queue does not exist.")
   WScript.Echo("Quitting.")
   WScript.Quit
Else
   Set queueFolder = objFSO.GetFolder(dataFolder & "\Queue")
End If

' Delete old "Queue.bak" folder if it exists
If objFSO.FolderExists(dataFolder & "\Queue.bak") Then
   Set queueFolderToDelete = objFSO.GetFolder(dataFolder & "\Queue.bak")
   queueFolderToDelete.Delete(true)
   WScript.Echo("Deleted old Queue.bak folder.")
End If

' Stop Microsoft Exchange Transport service
WScript.Echo("Stopping Microsoft Exchange Transport service...")
Set colListOfServices = objWMIService.ExecQuery("Select * from Win32_Service Where Name ='" & strServiceName & "'")
For Each objService in colListOfServices
    objService.StopService()
Next

' Sleep while Microsoft Exchange Transport service not completely stopped yet
Set colListOfServices = objWMIService.ExecQuery("Select * from Win32_Service Where Name ='" & strServiceName & "'")
For Each objService in colListOfServices
   strServiceState = objService.State
Next
While (strServiceState <> "Stopped")
   Set colListOfServices = objWMIService.ExecQuery("Select * from Win32_Service Where Name ='" & strServiceName & "'")
   For Each objService in colListOfServices
      strServiceState = objService.State
   Next
   WScript.Sleep(1000)
Wend
WScript.Sleep(5000)
WScript.Echo("Microsoft Exchange Transport service stopped.")

' Rename "Queue" folder to "Queue.bak"
objFSO.MoveFolder queueFolder, dataFolder & "\Queue.bak"

' Report completion
WScript.Echo("Mail queue cleared.")
WScript.Echo("Restart Microsoft Exchange Transport service or reboot server.")

