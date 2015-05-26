#!/usr/bin/env perl

################################################################################
# Description:
#    1. Prints current date, time, and SVN revision of:
#       * If '-i' option is specified: Root of working copy
#       * If a path is given:          Given directory
#       * If no path is given:         Current directory
#    2. Performs an SVN update on:
#       * If '-i' option is specified: Root of working copy
#       * If a path is given:          Given directory
#       * If no path is given:         Current directory
#    3. Calls 'svn_stat_aggregate.pl' to perform an SVN status, aggregating changelists across directories, on:
#       * If '-i' option is specified: List of directories in given file
#       * If a path is given:          Given directory
#       * If no path is given:         Current directory
#    * Printing of date and time useful for keeping a (pseudo) log of SVN updates in terminal scrollback
#    * Requires 'WORKSPACE' environment variable to be set to root of working copy, for 'svn info' and 'svn update'
#      commands
#    * Requires 'svn_stat_aggregate.pl' to be in the same directory
#
# Arguments:
#    * -i input-file
#      Path to file that contains a list of directories to retrieve status of, one per line
################################################################################


# Pragmas and modules
use Getopt::Std;
use File::Basename;
use Term::ANSIColor qw(:constants);

# Constants
use constant SVN_STATUS_SCRIPT_NAME => "svn_stat_aggregate.pl";


# Parse arguments
my @original_args = @ARGV;  # Save original arguments to later pass to SVN status script
getopts('i:');
my $directory;
my $option_string;
if ($opt_i) {  # Input file given
   # Check that environment variable 'WORKSPACE' is set
   if ($ENV{WORKSPACE} eq "") {  # Environment variable 'WORKSPACE' not set
      die(BOLD, RED, "Error: ", RESET, "Environment variable 'WORKSPACE' not set\n");
   }

   # Use root of working copy
   $directory = $ENV{WORKSPACE};
   $option_string = "root of working copy '$directory'";
}
else {  # No input file given
   # Search for path in list of arguments
   foreach $arg (@ARGV) {
      if ($arg !~ /^-/) {  # Found argument that does not begin with '-'
         # Use given directory
         $directory = $arg;
         $option_string = "given directory '$directory'";
         last;  # Stop processing arguments
      }
   }

   # Check whether a path was given
   if (!$directory) {  # No path given
      # Use current directory
      $directory = `pwd`; chomp($directory);
      $option_string = "current directory '$directory'";
   }
}

# Print current date and time
my $date = `date`; chomp($date);
print(BOLD, BLUE, "$date", RESET, "\n");

# Print selected option
print("Using $option_string\n");
print("\n");

# Print revision number
my $svn_info_revision_string = `svn info $directory | grep 'Revision'`;
my $revision_number;
if ($svn_info_revision_string =~ /(\d+)/) {
   $revision_number = $1;  # Capture revision number
}
else {  # No revision number
   die(BOLD, RED, "Error: ", RESET, "'$directory' is not a working copy\n");
}
my $path = ($opt_i) ? "Root of working copy"
                    : "Path";
print(BOLD, BLUE, "$path '$directory' is on revision $revision_number", RESET, "\n");

# Perform SVN update
print("Updating '$directory'...\n");
open(SVN_UP, "svn up $directory |") or die(BOLD, RED, "SVN update error: ", RESET, "$!\n");
while (<SVN_UP>) {
   print($_);
}
close(SVN_UP);
print("\n");

# Perform SVN status on given list of directories, aggregating changelists across directories
my $dirname = dirname($0);
my $svn_status_script_name = SVN_STATUS_SCRIPT_NAME;
if (-f "$dirname/$svn_status_script_name") {  # SVN status script exists
   open(SVN_STATUS, "/usr/bin/perl $dirname/$svn_status_script_name -d @original_args |");  # Do not print date, time, SVN revision
   while (<SVN_STATUS>) {
      print($_);
   }
   close(SVN_STATUS);
}
else {
   die(BOLD, RED, "Error: ", RESET, "SVN status script '$svn_status_script_name' does not exist\n");
}

# Print date and time of completion
$date = `date`; chomp($date);
print(BOLD, BLUE, "Completed $date", RESET, "\n");

