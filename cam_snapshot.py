#!/usr/bin/env python3

################################################################################
# Description:
#    * Takes a set of snapshots from internal camera using pre-determined
#      settings
#    * Requires that 'mplayer' player is available
#
# Arguments:
#    * --dry (optional)
#      Dry run; assembles and prints commands without executing them
#    * --help (optional)
#      Displays help message
#
# Examples:
#    * ./cam_snapshot.py
#    * ./cam_snapshot.py --dry
#    * ./cam_snapshot.py --help
#
# Limitations:
#    * Tested on only Fedora
################################################################################


# Modules
import argparse
import os
import shutil
import sys
import time

# Constants
BIN_PATHS = {"mplayer": "/usr/bin/mplayer"}
VIDEO_DEV = "/dev/video0"

# Main function
def main(argv):
    # Configure argument parser
    desc_str = "Takes a set of snapshots from internal camera using "
    desc_str += "pre-determined settings"
    parser = argparse.ArgumentParser(description=desc_str)
    parser.add_argument(
        "--dry",
        action="store_true",
        help="Assembles and prints commands without executing them"
    )

    # Print current time
    print(time.strftime("%a %Y-%m-%d %I:%M:%S %p"))
    print("")

    # Parse arguments
    print("Parsing arguments...")
    args = parser.parse_args()
    for (arg, val) in sorted(vars(args).items()):
        print("   * {}: {}".format(arg, val))
    print("")

    # Check that 'mplayer' video player is available
    check_player_exe()

    # Take snapshots
    take_snapshot(0, 10, not args.dry)  # Contrast 0, use 10th frame
    take_snapshot(20, 5, not args.dry)  # Contrast 20, use 5th frame

    # Exit
    print("Done.")
    print("")
    sys.exit(0)  # Success

# Checks that 'mplayer' video player is available
def check_player_exe():
    print("Checking that 'mplayer' video player is available...")

    if (shutil.which(BIN_PATHS["mplayer"], mode=os.X_OK)):
        print("'{}' executable found.".format(BIN_PATHS["mplayer"]))
        print("")
    else:
        msg = "'{}' executable not found.  ".format(BIN_PATHS["mplayer"])
        msg += "Verify that '{}' player is ".format(BIN_PATHS["mplayer"])
        msg += "installed."
        raise Exception(msg)

# Takes a snapshot with the given contrast and frame number settings
def take_snapshot(contrast, frames, live_run):
    # Capture set of still frames, 1 second apart
    msg = "Capturing {} still frames, ".format(frames)
    msg += "contrast {}, 1 second apart...".format(contrast)
    print(msg)
    cmd = "{} tv:// -tv".format(BIN_PATHS["mplayer"])
    cmd += " driver=v4l2:device={}".format(VIDEO_DEV)
    cmd += " -contrast {}".format(contrast)
    cmd += " -fps 1"
    cmd += " -frames {}".format(frames)
    cmd += " -sstep 100"
    cmd += " -vo jpeg"
    print(cmd)
    if (live_run):
        exit_status = os.system(cmd)
        if (exit_status != 0):
            msg = "Command '{}' failed ".format(cmd)
            msg += "with error code {}.".format(exit_status)
            raise Exception(msg)

    # Discard first frames, which are usually mangled or otherwise unreadable
    print("Discarding first {} frames:".format(frames))
    for n in range(1, frames):
        del_name = "{}.jpg".format(str(n).zfill(8))  # Pad to 8 digits
        print("   * Deleting '{}'...".format(del_name))
        if (live_run):
            os.remove(del_name)

    # Rename file to contain date stamp and contrast value
    print("Renaming file to contain date stamp and contrast value...")
    name_src = "{}.jpg".format(str(frames).zfill(8))  # Pad to 8 digits
    name_dst = time.strftime("%Y-%m-%d_%H%M_c{}.jpg".format(str(contrast).zfill(2)))
    print("Renaming '{}' to '{}'...".format(name_src, name_dst))
    if (live_run):
        os.rename(name_src, name_dst)

    print("")

# Execute 'main()' function
if (__name__ == "__main__"):
   main(sys.argv)

