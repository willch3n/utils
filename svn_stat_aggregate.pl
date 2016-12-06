#!/usr/bin/env perl

################################################################################
# Description:
#    1. Prints current date, time, and SVN revision of:
#       * If '-i' option is specified: Root of working copy
#       * If a path is given:          Given directory
#       * If no path is given:         Current directory
#    2. Performs an SVN status, aggregating changelists across directories, on:
#       * If '-i' option is specified: List of directories in given file
#       * If a path is given:          Given directory
#       * If no path is given:         Current directory
#    * Using this script to perform 'svn status' on only select directories rather than on entire working copy has been
#      observed to decrease run time from 10+ minutes to several seconds
#    * Requires 'WORKSPACE' environment variable to be set to root of working copy, for 'svn info' command
#
# Arguments:
#    * -i input-file
#      Path to file that contains a list of directories to operate on, one per line
#    * -d
#      Do not print current date, time, SVN revision, nor date and time of completion
################################################################################


# Pragmas and modules
use Getopt::Std;
use File::Basename;
use Term::ANSIColor qw(:constants);


# Parse arguments
getopts('di:');
my @directories;
my $option_string;
if ($opt_i) {  # Input file given
   # Check that environment variable 'WORKSPACE' is set
   if ($ENV{WORKSPACE} eq "") {  # Environment variable 'WORKSPACE' not set
      die(BOLD, RED, "Error: ", RESET, "Environment variable 'WORKSPACE' not set\n");
   }

   # Use list of directories in given input file
   open(INPUT, $opt_i) or die(BOLD, RED, "Error: ", RESET, "Read of input file '$opt_i' failed: $!\n");
   @directories = <INPUT>;  # Read file into array
   close(INPUT);  # Close file handle
   $option_string = "list of directories in given input file '$opt_i'";
}
else {  # No input file given
   # Search for path in list of arguments
   foreach $arg (@ARGV) {
      if ($arg !~ /^-/) {  # Found argument that does not begin with '-'
         # Use given directory
         push(@directories, $arg);  # Add given directory to list of directories to process
         $option_string = "given directory '$directories[0]'";
         last;  # Stop processing arguments
      }
   }

   # Check whether a path was given
   if ($#directories + 1 == 0) {  # No path given
      # Use current directory
      my $current_directory = `pwd`; chomp($current_directory);
      push(@directories, $current_directory);  # Add current directory to list of directories to process
      $option_string = "current directory '$directories[0]'";
   }
}

# Print current date, time, and SVN revision
if (!$opt_d) {
   # Print current date and time
   my $date = `date`; chomp($date);
   print(BOLD, BLUE, "$date", RESET, "\n");

   # Print selected option
   print("Using $option_string\n");
   print("\n");
}

# Print revision number
my $svn_info_directory = ($opt_i) ? $ENV{WORKSPACE}   # Root of working copy
                                  : $directories[0];  # Given or current directory
my $svn_info_revision_string = `svn info $svn_info_directory 2> /dev/null | grep 'Revision'`;
my $revision_number;
if ($svn_info_revision_string =~ /(\d+)/) {
   $revision_number = $1;  # Capture revision number
}
else {  # No revision number
   die(BOLD, RED, "Error: ", RESET, "'$svn_info_directory' is not a working copy\n");
}
my $path = ($opt_i) ? "Root of working copy"
                    : "Path";
print(BOLD, BLUE, "$path '$svn_info_directory' is on revision $revision_number", RESET, "\n");

# Perform SVN status on list of directories, aggregating changelists across directories
my %files;
foreach $directory (@directories) {
   # Process read line
   chomp($directory);                   # Remove trailing newline character
   $directory =~ s/\$(\w+)/$ENV{$1}/g;  # Expand environment variables

   # Retrieve status of each directory
   my @directory_split = split(' ', $directory);  # Split read line into path and arguments
   my $isolated_path = shift(@directory_split);   # Extract path from arguments
   if (-d $isolated_path) {  # Directory exists
      if ($#directory_split > 0) {  # Line contains one or more arguments
         print("Retrieving status of '$isolated_path' using arguments '@directory_split'...\n");
      }
      else {  # Line contains no arguments
         print("Retrieving status of '$isolated_path'...\n");
      }

      # Perform SVN status on directory, including any arguments
      my @top_level_status_lines = `svn stat --ignore-externals $isolated_path @directory_split`;

      # Process files not in any changelists
      foreach $status_line (@top_level_status_lines) {
         chomp($status_line);  # Remove trailing newline character

         # Stop processing lines if changelist found
         last if ($status_line =~ /--- Changelist '.*':/);

         # Add all files that are not in any changelists to special '_not_in_any_changelists_' element
         if ($status_line ne "") {  # Line not blank
            push(@{$files{"_not_in_any_changelists_"}}, $status_line);
         }
      }

      # Process files in changelists
      foreach $status_line (@top_level_status_lines) {
         chomp($status_line);  # Remove trailing newline character

         # Process each changelist
         if ($status_line =~ /--- Changelist '([\w-]+)':/) {  # Match alphanumeric characters, underscores, and hyphens
            my $changelist_name = $1;

            # Process changelist
            foreach $changelist_status_line (`svn stat --ignore-externals $isolated_path @directory_split --cl $1`) {
               chomp($changelist_status_line);  # Remove trailing newline character

               # Add all files in changelist to hash
               if (($changelist_status_line ne "") && ($changelist_status_line !~ /--- Changelist '.*':/)) {  # Item
                  push(@{$files{$changelist_name}}, $changelist_status_line);
               }
            }  # Process changelist
         }  # Process each changelist
      }  # For each status line of directory
   }  # Directory exists
   elsif ($directory ne "") {  # Line not blank, but directory does not exist
      print(BOLD, YELLOW, "Warning: ", RESET, "Directory '$isolated_path' does not exist or is inaccessible\n");
   }
}
print("\n");

# Print each item in each changelist, if any
print(BOLD, BLUE, "Aggregated status:", RESET, "\n");
my $num_changelists = keys(%files);
if ($num_changelists > 0) {  # At least one change
   foreach $changelist (sort(keys(%files))) {  # Sort alphabetically
      # Retrieve number of files in changelist
      my $num_files_in_changelist = $#{$files{$changelist}} + 1;  # Count begins at 0
      my $files_string = ($num_files_in_changelist == 1) ? "file"    # 1 file
                                                         : "files";  # 0 files / N files

      # Print header
      if ($changelist eq "_not_in_any_changelists_") {
         print("--- Not in any changelists ($num_files_in_changelist $files_string):\n");
      }
      else {
         print("--- Changelist '$changelist' ($num_files_in_changelist $files_string):\n");
      }

      # Print each item in changelist
      foreach $item (@{$files{$changelist}}) {
         print("$item\n");
      }

      print("\n");
   }
}
else {  # No changes
   print("No changes.\n");
   print("\n");
}

# Print current revision number again, in case 'status' output consumes more than one screen of scrollback
print(BOLD, BLUE, "$path '$svn_info_directory' is on revision $revision_number", RESET, "\n");

# Print date and time of completion
if (!$opt_d) {
   $date = `date`; chomp($date);
   print(BOLD, BLUE, "Completed $date", RESET, "\n");
}

