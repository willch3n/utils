#!/usr/bin/env perl

################################################################################
# Description:
#    * Uploads Foscam recordings to an FTP server, organising them by date
#       1. Lists recordings by day, along with each day's count and size
#       2. Prompts for the password of the user specified in the configuration file
#       3. Uploads recordings to the FTP server specified in the configuration file, creating a directory structure of
#          year, month, and date
#    * Requires a configuration file containing the following parameters, one per line:
#       * remote_ftp_hostname = ftp.my_ftp_host.com
#       * ftp_user_name       = my_user_name
#       * local_source_path   = /home/local_user_name/ftp_dir/FI9821W_00112233AABB/record
#       * remote_dest_path    = /Media/Surveillance
#    * Requires that 'lftp' client is available
#
# Arguments:
#    * -c path_to_config_file_rc
#      Optional path to configuration file; if not given, looks for '~/.upload_foscam_recordings_rc'
#    * -d
#      Dry run; skips all actions that make modifications, such as FTP 'mkdir' and 'mirror' commands
#
# Limitations:
#    * Assumes that recordings are named according to the pattern 'MDalarm_YYYYMMDD_HHMMSS.mkv'
#    * Does not delete recordings after uploading them
################################################################################


# Pragmas and modules
use strict;
use warnings;
use Getopt::Std;
use IO::Prompter;

# Variables
my $config_file_path = glob("~/.upload_foscam_recordings_rc");  # Use 'glob' to expand tilde
my $dry_run = 0;
my $remote_ftp_hostname;
my $ftp_user_name;
my $local_source_path;
my $remote_dest_path;


# Parse arguments
printf("Parsing arguments...\n");
our $opt_c;
our $opt_d;
getopts('c:d');
if (defined($opt_c)) {  # Path to custom configuration file given
   $config_file_path = $opt_c;
   printf("   * -c: Path to custom configuration file '$config_file_path'\n");
}
if (defined($opt_d)) {  # 'Dry run' option specified
   $dry_run = 1;
   printf("   * -d: Dry run\n");
}

# Check existence of configuration file
my $custom_or_default_str = (defined($opt_c)) ? "Custom" : "Default";
$config_file_path = glob("$config_file_path");  # Use 'glob' to expand tilde, if any
if (!(-f "$config_file_path")) {  # Configuration file not found
   die("Error: $custom_or_default_str configuration file '$config_file_path' not found!\n");
}
else {  # Configuration file found
   printf("Loading %s configuration file '%s'...\n", lc($custom_or_default_str), $config_file_path);
}

# Read and parse configuration file
open(CONFIG, "< $config_file_path") or die("Error: Read of file '$config_file_path' failed: $!\n");  # Read-only
while (<CONFIG>) {
   chomp($_);  # Remove trailing newline
   if ($_ =~ /^[^#].*/) {  # Not a comment
      if    ($_ =~ /remote_ftp_hostname\s+=\s+(\S+)(?:\s?)+#?/) {$remote_ftp_hostname = $1;}
      elsif ($_ =~ /ftp_user_name\s+=\s+(\S+)(?:\s?)+#?/      ) {$ftp_user_name       = $1;}
      elsif ($_ =~ /local_source_path\s+=\s+(\S+)(?:\s?)+#?/  ) {$local_source_path   = $1;}
      elsif ($_ =~ /remote_dest_path\s+=\s+(\S+)(?:\s?)+#?/   ) {$remote_dest_path    = $1;}
   }
}
my $missing = 0;
if (!defined($remote_ftp_hostname)) {$missing = 1; printf("Error: 'remote_ftp_hostname' undefined!\n")};
if (!defined($ftp_user_name)      ) {$missing = 1; printf("Error: 'ftp_user_name' undefined!\n")      };
if (!defined($local_source_path)  ) {$missing = 1; printf("Error: 'local_source_path' undefined!\n")  };
if (!defined($remote_dest_path)   ) {$missing = 1; printf("Error: 'remote_dest_path' undefined!\n")   };
if ($missing) {
   die("Error: One or more configuration parameters undefined\n");
}
print("Remote FTP hostname:     $remote_ftp_hostname\n");
print("FTP user name:           $ftp_user_name\n");
print("Local source path:       $local_source_path\n");
print("Remote destination path: $remote_dest_path\n");
print("\n");
close(CONFIG);  # Close configuration file handle

# Verify existence of local source directory
if (!-d $local_source_path) {  # Local source directory does not exist
   die("Error: Local source directory '$local_source_path' does not exist!\n");
}

# Retrieve contents of local source directory and populate array of file names
my @files;
opendir(LOCAL_SOURCE_DIR, $local_source_path) or die ("Error: Read of '$local_source_path' failed: $!!\n");
while (defined(my $file = readdir(LOCAL_SOURCE_DIR))) {
   if (($file ne "."                 ) and  # Exclude listing for current directory
       ($file ne ".."                ) and  # Exclude listing for parent directory
       (-f "$local_source_path/$file")) {   # Is a file, not a directory
      push(@files, $file);
   }
}
close(LOCAL_SOURCE_DIR);  # Close directory handle

# Build hash of unique days, containing count for each day
my %days;
my $today_string = `date +%Y%m%d`; chomp($today_string);
foreach my $file (@files) {
   if ($file =~ /MDalarm_(\d{4})(\d{2})(\d{2}).*\.mkv/) {
      my ($yyyy, $mm, $dd) = ($1, $2, $3);
      my $date_string = $yyyy . $mm . $dd;
      if ($date_string ne $today_string) {  # Exclude current day
         $days{$date_string} += 1;  # Increment count for day
      }
   }
}

# Compute total number of files found in local source directory, excluding those for current day
my $num_files_found = 0;
foreach my $day (keys(%days)) {  # For each day
   $num_files_found += $days{$day};  # Add count for day to total count
}
my $num_unique_days = scalar(keys(%days));
$today_string       = `date +%Y-%m-%d`; chomp($today_string);
printf("Found a total of %s recordings made over %s days, excluding today (%s):\n",
       $num_files_found, $num_unique_days, $today_string);
if ($num_files_found <= 0) {
   printf("No files to upload; exiting.\n");
   exit 1;
}

# Print counts and sizes for each day
printf("+----------+-------+----------+\n");
printf("| Day      | Count | Size     |\n");
printf("+----------+-------+----------+\n");
foreach my $day (sort(keys(%days))) {  # Sort alphabetically
   my $wildcard_string = "$local_source_path/MDalarm_" . $day . "_*";
   my $count           = `ls $wildcard_string | wc -l`;
   my $size            = `du -shc $wildcard_string | grep 'total' | awk '{print \$1}'`; chomp($size);
   printf("| $day | %5d | %8s |\n", $count, $size);
}
printf("+----------+-------+----------+\n");
print("\n");

# Prompt for password and call 'lftp' to connect
my $password = prompt("Enter password of '$ftp_user_name' on '$remote_ftp_hostname': ", -echo => '*');
print("Connecting to '$remote_ftp_hostname' as '$ftp_user_name'...\n");
my $lftp_command = "lftp -p 990 ftps://$remote_ftp_hostname -u $ftp_user_name,$password";
open(LFTP_PIPE, '|-', $lftp_command) or die("Error: Could not open 'lftp' pipe: $!!\n");

# Set configuration variables
print(LFTP_PIPE "set cmd:default-protocol ftps\n");
print(LFTP_PIPE "set ftp:passive-mode on\n");
print(LFTP_PIPE "set ftp:ssl-allow yes\n");
print(LFTP_PIPE "set ftp:ssl-force true\n");
print(LFTP_PIPE "set ftp:ssl-protect-data true\n");
print(LFTP_PIPE "set ftps:initial-prot \"\"\n");

# For each day, reverse-mirror recordings from local source directory to remote destination directory, creating
# directory structure as we go
foreach my $day (sort(keys(%days))) {  # Sort alphabetically
   # Create directory structure for day, without checking whether structure already exists ('lftp' automatically
   # refuses to re-create directories that already exist)
   my ($yyyy, $mm, $dd);
   if ($day =~ /(\d{4})(\d{2})(\d{2})/) {
      ($yyyy, $mm, $dd) = ($1, $2, $3);
   }
   print("Uploading recordings from $yyyy-$mm-$dd...\n");
   my $mkdir_yyyy_cmd       = "mkdir $remote_dest_path\/$yyyy";
   my $mkdir_yyyy_mm_cmd    = "mkdir $remote_dest_path\/$yyyy\/$yyyy-$mm";
   my $mkdir_yyyy_mm_dd_cmd = "mkdir $remote_dest_path\/$yyyy\/$yyyy-$mm\/$yyyy-$mm-$dd";
   print("Executing command: '$mkdir_yyyy_cmd'...\n");
   print("Executing command: '$mkdir_yyyy_mm_cmd'...\n");
   print("Executing command: '$mkdir_yyyy_mm_dd_cmd'...\n");
   if (!$dry_run) {  # Not dry run
      print(LFTP_PIPE "$mkdir_yyyy_cmd\n");
      print(LFTP_PIPE "$mkdir_yyyy_mm_cmd\n");
      print(LFTP_PIPE "$mkdir_yyyy_mm_dd_cmd\n");
   }

   # Reverse-mirror recordings for day to remote destination directory
   my $wildcard_string = "MDalarm_" . $day . "_*";
   my $full_remote_dest_path = "$remote_dest_path\/$yyyy\/$yyyy-$mm\/$yyyy-$mm-$dd";
   my $mirror_cmd = "mirror -R -i $wildcard_string $local_source_path $full_remote_dest_path";
   print("Executing command: '$mirror_cmd'...\n");
   if (!$dry_run) {  # Not dry run
      print(LFTP_PIPE "$mirror_cmd\n");
   }
}

# Close pipe
close(LFTP_PIPE);

# Exit
exit 0;

