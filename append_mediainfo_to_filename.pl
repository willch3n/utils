#!/usr/bin/env perl

################################################################################
# Description:
#    * Appends media information to the names of all video files in the given directory:
#       * Resolution (480p, 720p, 1080p)
#       * Number of audio channels (2ch, 6ch)
#
# Arguments:
#    * -r
#      Enables renaming of files; otherwise, merely prints out what the new file names would become if renames were
#      enabled
#
# Examples:
#    * Matrix (1999).wmv        -> Matrix (1999) [720p 6ch].wmv
#    * Star Trek (2009).mkv     -> Star Trek (2009) [720p 6ch].mkv
#    * TRON - Legacy (2010).mkv -> TRON - Legacy (2010) [1080p 6ch].mkv
#
# Limitations:
#    * Does not recognise when a file already has media information appended
#    * Does not attempt to synchronise names of subtitle files (*.srt) with those of video files
#    * Files with multiple audio streams result in unexpected channel counts; for instance, a file with both a
#      6-channel stream and a 2-channel stream would be appended with '62ch'
################################################################################


# Pragmas and modules
use Getopt::Std;
use File::Basename;

# Constants
use constant MEDIAINFO_PATH  => "E:\\MediaInfo_CLI_0.7.62_Windows_i386\\MediaInfo.exe";
use constant MIN_1080p_WIDTH => 1900;
use constant MIN_720p_WIDTH  => 1100;
use constant MIN_480p_WIDTH  => 600;


# Parse arguments
getopts('r');
my $num_args = $#ARGV + 1;  # Count begins at 0
my $directory;
if ($num_args != 1) {  # Expect exactly 1 argument
   my $script_name = basename($0);
   die("Usage: $script_name directory\n");
}
else {  # 1 argument given
   $directory = shift(@ARGV);
}

# If directory exists, retrieve all files in directory
my @files;
if (!-d $directory) {  # Directory does not exist
   die("Error: Directory '$directory' does not exist\n");
}
else {  # Directory exists
   # Retrieve contents of directory and populate array
   opendir(INPUT, $directory) or die ("Read of input directory '$directory' failed: $!\n");
   while(defined($file = readdir(INPUT))) {
      if (($file ne "."          ) &&  # Exclude listing for current directory
          ($file ne ".."         ) &&  # Exclude listing for parent directory
          (-f "$directory\\$file")) {  # Is a file, not a directory
         push(@files, $file);
      }
   }
   close(INPUT);  # Close directory handle

   # Print number of files found
   my $num_files_found = $#files + 1;  # Count begins at 0
   print("Found $num_files_found files in '$directory'\n");
   print("\n");
}

# Determine length of longest file name in directory
my $length_of_longest_file_name = 4;
foreach $file (@files) {
   my $file_name_length = length($file);
   if ($file_name_length > $length_of_longest_file_name) {
      $length_of_longest_file_name = $file_name_length;
   }
}

# Print column headers
printf("%-".$length_of_longest_file_name."s | %5s | %18s | %s\n",
       "File", "Width", "Information string", "New file name");
printf("%-".$length_of_longest_file_name."s-+-%5s-+-%18s-+-%s\n",
       "-" x $length_of_longest_file_name, "-" x 5, "-" x 18, "-" x 20);

# Operate on each file in directory
my $files_renamed;
foreach $file (@files) {
   # Obtain media information
   my $mediainfo_path = MEDIAINFO_PATH;  # FIXME: Is this really necessary?
   my $width = `$mediainfo_path --output=Video;%Width% \"$directory\\$file\"`;
   my $channels = `$mediainfo_path --output=Audio;%Channels% \"$directory\\$file\"`;
   chomp($width); chomp($channels);  # Remove trailing newline characters

   # Determine whether file is a video file
   my $is_video_file = ($width ne "");

   # Build information string to append to file name
   my $information_string;
   my $new_file_name;
   if ($is_video_file) {  # Is a video file
      # Parse media information
      my $resolution_descriptor = ($width >= MIN_1080p_WIDTH) ? "1080p"
                                : ($width >= MIN_720p_WIDTH)  ? "720p"
                                : ($width >= MIN_480p_WIDTH)  ? "480p"
                                :                               "SD";

      # Build information string
      $information_string = sprintf("[%s %sch]",
                                    $resolution_descriptor, $channels);

      # Build new file name
      my ($filename, $path_unused, $suffix) = fileparse($file, qr/\.[^.]*/);  # Resultant path is unused
      $new_file_name = sprintf("%s %s%s",
                               $filename, $information_string, $suffix);
   }

   # Print file name, video width, information string, and new file name
   printf("%-".$length_of_longest_file_name."s | %5s | %18s | %s\n",
          $file, $width, $information_string, $new_file_name);

   # If video file and renames enabled, perform rename
   if ($is_video_file && $opt_r) {  # Video file and renames enabled
      if (rename("$directory\\$file", "$directory\\$new_file_name")) {  # Rename successful
         $files_renamed++;
      }
   }
}
print("\n");

# Print number of files renamed
if ($opt_r) {  # Renames enabled
   printf("$files_renamed files renamed\n");
}
else {  # Renames disabled
   printf("Use '-r' option to perform renames\n");
}

