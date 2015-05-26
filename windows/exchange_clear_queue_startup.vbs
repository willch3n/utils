''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Originally written on 2010-05-05
'    * Clears Exchange mail queue
'       * Checks whether Microsoft Exchange Transport service is running; aborts if so
'       * Renames "Queue" folder to "Queue.bak"
'       * Starts Microsoft Exchange Transport service
'    * Intended to be executed as a startup script
'    * Used to work around bug that causes already-sent mail to be sent out again upon reboot
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Variables and constants
Dim objFSO, objShell, dataFolder, queueFolder, queueFolderToDelete, objWMIService
Dim strServiceName, colListOfServices, objService, strServiceState, objLog
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objShell = WScript.CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
logfile = "C:\Windows\Logs\exchange_clear_queue_startup.log"
Set objLog = objFSO.OpenTextFile(logfile, 8, True)
Set dataFolder = objFSO.GetFolder("C:\Program Files\Microsoft\Exchange Server\V14\TransportRoles\data")
strServiceName = "MSExchangeTransport"


' Write log entry headers
objLog.WriteLine("")
objLog.WriteLine("----- " & Date & " " & Time & " -----")

' Check existence of "Queue" folder
If Not objFSO.FolderExists(dataFolder & "\Queue") Then
   objLog.WriteLine(dataFolder & "\Queue does not exist.")
   objLog.WriteLine("Aborting.")
   WScript.Quit
Else
   Set queueFolder = objFSO.GetFolder(dataFolder & "\Queue")
End If

' Delete old "Queue.bak" folder if it exists
If objFSO.FolderExists(dataFolder & "\Queue.bak") Then
   Set queueFolderToDelete = objFSO.GetFolder(dataFolder & "\Queue.bak")
   queueFolderToDelete.Delete(true)
   objLog.WriteLine("Deleted old Queue.bak folder.")
End If

' Abort if Microsoft Exchange Transport service is running
Set colListOfServices = objWMIService.ExecQuery("Select * from Win32_Service Where Name ='" & strServiceName & "'")
For Each objService in colListOfServices
   strServiceState = objService.State
Next
If strServiceState <> "Stopped" Then
   objLog.WriteLine("Microsoft Exchange Transport service is running.")
   objLog.WriteLine("Aborting.")
   WScript.Quit
End If

' Rename "Queue" folder to "Queue.bak"
objFSO.MoveFolder queueFolder, dataFolder & "\Queue.bak"
objLog.WriteLine("Renamed Queue folder to Queue.bak.")

' Start Microsoft Exchange Transport service
objShell.Run("net start MSExchangeTransport")
objLog.WriteLine("Started Microsoft Exchange Transport service.")

