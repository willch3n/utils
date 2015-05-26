''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Originally written on 2009-05-14
'    * Copies Outlook PST file to a directory that is being synced by Windows Live Mesh
'    * In the process, changes file extension from '.pst' to '.pstbak' to circumvent Live Mesh's file type filter
'    * If a backup already exists, prompts user before overwriting it
'
' Limitations:
'    * Doesn't do much error checking
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Variables
Dim strYear, strMonth, strDay, folderName
Dim ObjFSO, SourceFolder, DestFolder
Dim OrigName, NewName
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set SourceFolder = objFSO.GetFolder("C:\Users\user_name\AppData\Local\Microsoft\Outlook")
Set DestFolder   = objFSO.GetFolder("D:\PST backups")


' If Outlook is running, exit
Set service = GetObject("winmgmts:")
For Each Process in Service.InstancesOf("Win32_Process")
   If Process.Name = "OUTLOOK.EXE" Then
      WScript.Quit
   End If
Next

' Build date string in format YYYY-MM-DD
strYear = DatePart("yyyy", Date)
If DatePart("m", Date) < 10 Then
   strMonth = 0 & DatePart("m", Date)
Else
   strMonth = DatePart("m", Date)
End If
If DatePart("d", Date) < 10 Then
   strDay = 0 & DatePart("d", Date)
Else
   strDay = DatePart("d", Date)
End If
folderName = strYear & " - " & strMonth & "-" & strDay

' Check whether backup for current day already exists
' If so, prompt whether to replace and delete existing backup
If objFSO.FolderExists(DestFolder & "\" & folderName) Then
   Dim replaceP
   replaceP = MsgBox("""" & DestFolder & "\" & folderName & """ already exists.  Replace existing backup?", 36, _
                     "Replace existing backup?")
   If replaceP=7 Then
      WScript.Echo "Keeping existing backup and quitting."
      WScript.Quit
   End If
   Set objDelExistingBackup = objFSO.GetFolder(DestFolder & "\" & folderName)
   objDelExistingBackup.Delete(true)
End If

' Copy PST folder
SourceFolder.Copy(DestFolder & "\" & folderName)

' Change extension of PST file to ".pstbak"
OrigName = DestFolder & "\" & folderName & "\Outlook.pst"
NewName  = DestFolder & "\" & folderName & "\Outlook.pstbak"
objFSO.MoveFile OrigName, NewName

' Report success
WScript.Echo "PST folder backed up."

