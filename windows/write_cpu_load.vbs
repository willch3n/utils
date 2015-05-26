''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
' Description:
'    * Last revised on 2009-10-21
'    * Writes following information to a file named 'cpu_load.txt':
'       * Current date and time
'       * Current CPU load percentage
'       * Current CPU clock frequency
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''


' Variables and constants
Dim objFSO, outputFile
Dim objCPU
Set objFSO = CreateObject("Scripting.FileSystemObject")
Const outputFileName = "cpu_load.txt"
Set outputFile = objFSO.OpenTextFile(outputFileName, 2, True)


' Write CPU load percentage to outputFile
outputFile.WriteLine(date() & " " & time())
outputFile.WriteLine(currentCPULoad() & "% CPU Load")
outputFile.WriteLine(currentCPUClock() & " MHz")

' Returns current CPU load percentage
Function currentCPULoad()
   For each objCPU in GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2").InstancesOf("Win32_Processor")
      currentCPULoad = objCPU.LoadPercentage
   Next
End Function

' Returns current CPU clock speed
Function currentCPUClock()
   For each objCPU in GetObject("winmgmts:{impersonationLevel=impersonate}\\.\root\cimv2").InstancesOf("Win32_Processor")
      currentCPUClock = objCPU.CurrentClockSpeed
   Next
End Function

