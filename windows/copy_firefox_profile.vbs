''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Originally written on 2009-05-14
'    * Copies Firefox profile from laptop (NEBUCHADNEZZAR) to desktop (LOGOS)
'    * This was useful back before Mozilla added Firefox Sync
'
' Limitations:
'    * Lots of stuff is hard-coded
'    * Doesn't do much error checking
'    * Intended to be run from desktop (LOGOS) only
'    * Assumes that both machines are powered on and on the same network
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Variables
Dim ObjFSO, LaptopProfileFolder, LaptopSubFolders, objFileCopy, i, j
Dim DesktopProfileFolder, DesktopSubFolders, strDesktopProfileName
Set objFSO = CreateObject("Scripting.FileSystemObject")


' Prompt user to ensure that Firefox is running on neither source nor destination machine
Dim runP
runP = MsgBox ("Ensure that Firefox is not running on either NEBUCHADNEZZAR nor LOGOS, and that NEBUCHADNEZZAR is " & _
               "powered on.", 49, "Firefox Profile Copy Script")
If runP <> 1 Then
   WSCript.Echo "Shut down Firefox on both systems, then run this script again."
   WScript.Quit
End If

' Retrieve folder handles
Set LaptopProfileFolder = objFSO.GetFolder("\\NEBUCHADNEZZAR\c$\Users\user_name\AppData\Roaming\Mozilla\Firefox\Profiles")
Set LaptopSubFolders = LaptopProfileFolder.SubFolders
Set DesktopProfileFolder = objFSO.GetFolder("C:\Users\user_name\AppData\Roaming\Mozilla\Firefox\Profiles")
Set DesktopSubFolders = DesktopProfileFolder.SubFolders

' Check that only one profile exists
If LaptopSubFolders.Count <> 1 Then
   WScript.Echo "Error: More than one profile in source folder."
   WScript.Quit
End If
If DesktopSubFolders.Count <> 1 Then
   WScript.Echo "Error: More than one profile in destination folder."
   WScript.Quit
End If

' Copy each file within profile
For Each j in DesktopSubFolders
   strDesktopProfileName = j.Name
Next
For Each i in LaptopSubFolders
   Set objFileCopy          = objFSO.GetFolder("\\NEBUCHADNEZZAR\c$\Users\user_name\AppData\Roaming\Mozilla\" & _
                                               "Firefox\Profiles\" & i.Name)
   Set objDelDesktopProfile = objFSO.GetFolder("C:\Users\user_name\AppData\Roaming\Mozilla\Firefox\Profiles\" & _
                                               strDesktopProfileName)
   objDelDesktopProfile.Delete(true)
   objFileCopy.Copy("C:\Users\user_name\AppData\Roaming\Mozilla\Firefox\Profiles\" & strDesktopProfileName)
Next

' Report success
WScript.Echo "Profile copied."

