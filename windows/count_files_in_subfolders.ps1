################################################################################
# Description:
#    * Prints the number of files in each subfolder of a path, recursively
################################################################################


# Variables
$f_drive = "F:"


# Count files
foreach ($folder in get-childitem $f_drive | where-object {$_.psiscontainer}) {
   $name = $folder | select name
   $count = (get-childitem -recurse $photos\$folder | where-object {!$_.psiscontainer}).count   
   "$name $count"
}

