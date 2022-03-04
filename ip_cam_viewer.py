#!/usr/bin/env python3

################################################################################
# Description:
#    * Displays a grid of RTSP streams from IP cameras
#    * Outputs to display attached to HDMI port of Raspberry Pi
#    * Requires that 'omxplayer' video player is available
#    * Expects a configuration file in home directory named
#      '.ip_cam_viewer_cfg.json', in the following format:
#      {
#         "streams": [
#            {"name": "cam_0_name", "uri": "rtsp://username:password@foo.bar.com:port/"},
#            {"name": "cam_1_name", "uri": "rtsp://username:password@foo.bar.com:port/"}
#         ]
#      }
#
# Arguments:
#    * action (required)
#      Action to take; valid values are 'start', 'repair', and 'stop'
#    * --dry (optional)
#      Dry run; assembles and prints commands without executing them
#    * --help (optional)
#      Displays help message
#
# Examples:
#    * ./ip_cam_viewer.py start
#    * ./ip_cam_viewer.py stop
#    * ./ip_cam_viewer.py --help
#
# Limitations:
#    * Fills available display area without retaining aspect ratios
#    * Tested on only Raspberry Pi 3 Model B
################################################################################


# Modules
import sys
import os
import time
import shutil
import argparse
import json

# Constants
BIN_PATHS = {"screen"   : "/usr/bin/screen",
             "grep"     : "/bin/grep",
             "omxplayer": "/usr/bin/omxplayer"}
CFG_FILE_PATH = "~/.ip_cam_viewer_cfg.json"
PLAYER_OPTS = "--avdict rtsp_transport:tcp --live -n -1"
SCR_SESS_PREFIX = "ip_cam"
DISP_RES_X = 1920
DISP_RES_Y = 1080
FPS = 5

# Main function
def main(argv):
    # Configure argument parser
    desc_str = "Displays a grid of RTSP streams from IP cameras,"
    desc_str += " outputting to display attached to HDMI port of Raspberry Pi."
    parser = argparse.ArgumentParser(description=desc_str)
    parser.add_argument(
        "action",
        choices=["start", "repair", "stop"],
        help="Action to take"
    )
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

    # Check that 'omxplayer' video player is available
    if (args.action in ["start", "repair"]):
        check_player_exe()

    # Parse configuration file
    cfg_file_path = os.path.expanduser(CFG_FILE_PATH)
    cfg_file_path = os.path.expandvars(cfg_file_path)
    print("Parsing configuration file '{}'...".format(cfg_file_path))
    cfg = json.load(open(cfg_file_path))
    check_cfg_file(cfg)  # Check that file contains all required information
    print("")

    # Take requested action
    if   (args.action == "start"):  start_streams(cfg, not args.dry)
    elif (args.action == "repair"): repair_streams(cfg, not args.dry)
    elif (args.action == "stop"):   stop_streams(cfg, not args.dry)

    # Exit
    print("Done.")
    print("")
    sys.exit(0)  # Success

# Checks that 'omxplayer' video player is available
def check_player_exe():
    print("Checking that 'omxplayer' video player is available...")

    if (shutil.which(BIN_PATHS["omxplayer"], mode=os.X_OK)):
        print("'{}' executable found.".format(BIN_PATHS["omxplayer"]))
        print("")
    else:
        msg = "'{}' executable not found.  ".format(BIN_PATHS["omxplayer"])
        msg += "Verify that device is a Raspberry Pi, and that "
        msg += "'{}' video player is installed.".format(BIN_PATHS["omxplayer"])
        raise Exception(msg)

# Checks that configuration file contained all required information
def check_cfg_file(cfg):
    # Streams
    if ("streams" in cfg):
        if (len(cfg["streams"]) > 0):  # Parsed list contains at least one item
            msg = "Parsed {} streams ".format(len(cfg["streams"]))
            msg += "from configuration file:"
            print(msg)
            for stream in cfg["streams"]:
                if ("uri" in stream):  # 'uri' element found for stream
                    print("   * {}: {}".format(stream["name"], stream["uri"]))
                else:  # No 'uri' element found for stream
                    msg = "No 'uri' element found for "
                    msg += "stream '{}'".format(stream["name"])
                    raise Exception(msg)
        else:  # Parsed 'streams[]' list is empty
            msg = "Configuration file 'streams[]' list is empty."
            raise Exception(msg)
    else:  # No 'streams[]' list found
        msg = "Configuration file does not contain a 'streams[]' list."
        raise Exception(msg)

# Starts streams, skipping any that are already running
def start_streams(cfg, live_run):
    # Set dimensions of grid according to number of streams to be displayed
    if (len(cfg["streams"]) == 1):  # Single stream
        (grid_sz_x, grid_sz_y) = (1, 1)
    elif (len(cfg["streams"]) in range(2, 5)):  # 2, 3, or 4 streams
        (grid_sz_x, grid_sz_y) = (2, 2)
    elif (len(cfg["streams"]) in range(5, 7)):  # 5 or 6 streams
        (grid_sz_x, grid_sz_y) = (3, 2)
    else:  # Unsupported number of streams
        msg = "Maximum number of streams supported is 6, but "
        msg += "{} streams specified.".format(len(cfg["streams"]))
        raise Exception(msg)
    print("Grid dimensions: {} x {}".format(grid_sz_x, grid_sz_y))

    # Start streams
    print("Starting streams...")
    for (idx, stream) in enumerate(cfg["streams"]):
        # If screen session for this index already exists, let it carry on
        if (check_screen_session_exists(idx)):
            msg = "Screen session '{}_{}' ".format(SCR_SESS_PREFIX, idx)
            msg += "already exists; skipping."
            print(msg)
            continue

        # Otherwise, assemble and execute start command
        win_pos_str = win_pos(
            grid_sz_x,  # Width of grid
            grid_sz_y,  # Height of grid
            idx % grid_sz_x,  # X coordinate of current stream
            idx // grid_sz_x,  # Y coordinate of current stream
        )
        start_cmd = "{} {}".format(BIN_PATHS["omxplayer"], PLAYER_OPTS)
        start_cmd += " --win {}".format(win_pos_str)
        start_cmd += " --fps {}".format(FPS)
        start_cmd += " {}".format(stream["uri"])
        start_cmd = "{} -dmS {}_{} bash -c '{}'".format(
            BIN_PATHS["screen"],
            SCR_SESS_PREFIX,
            idx,
            start_cmd
        )
        print(start_cmd)
        if (live_run):
            exit_status = os.system(start_cmd)
            if (exit_status != 0):
                msg = "Command '{}' failed ".format(start_cmd)
                msg += "with error code {}.".format(exit_status)
                raise Exception(msg)

    print("")

# Repairs streams by stopping them all, and then starting them anew
def repair_streams(cfg, live_run):
    print("Repairing streams...")
    print("")

    stop_streams(cfg, live_run)
    time.sleep(1)
    start_streams(cfg, live_run)

# Stops all streams
def stop_streams(cfg, live_run):
    print("Stopping streams...")

    for (idx, stream) in enumerate(cfg["streams"]):
        # If session does not exist, do not attempt to stop it
        if (not check_screen_session_exists(idx)):
            msg = "Screen session '{}_{}' ".format(SCR_SESS_PREFIX, idx)
            msg += "already stopped; skipping."
            print(msg)
            continue

        # Otherwise, stop it
        stop_cmd = "{} -S {}_{} -X quit".format(
            BIN_PATHS["screen"],
            SCR_SESS_PREFIX,
            idx
        )
        print(stop_cmd)
        if (live_run):
            exit_status = os.system(stop_cmd)
            if (exit_status != 0):
                msg = "Command '{}' failed ".format(stop_cmd)
                msg += "with error code {}.".format(exit_status)
                raise Exception(msg)

    print("")

# Checks whether a screen session of the given index is already running
def check_screen_session_exists(session_idx):
    # Check that 'grep' is available
    if (not shutil.which(BIN_PATHS["grep"], mode=os.X_OK)):
        msg = "'{}' executable not found.".format(BIN_PATHS["grep"])
        raise Exception(msg)

    # List active screen sessions and search through it
    check_cmd = "{} -list | {} '\.{}_{}\s'".format(
        BIN_PATHS["screen"],
        BIN_PATHS["grep"],
        SCR_SESS_PREFIX,
        session_idx
    )
    return (os.system(check_cmd) == 0)

# Given grid dimensions and coordinates, computes the pixel coordinates of the
# corresponding bounding box, in a string to be provided to 'omxplayer' via its
# '--win' option
def win_pos(grid_sz_x, grid_sz_y, x, y):
    # Compute X and Y sizes of each stream
    x_sz = int(DISP_RES_X / grid_sz_x)
    y_sz = int(DISP_RES_Y / grid_sz_y)

    # Compute pixel coordinates of top-left and bottom-right corners of
    # bounding box
    top_left_x = x * x_sz
    top_left_y = y * y_sz
    bot_right_x = top_left_x + x_sz
    bot_right_y = top_left_y + y_sz

    # Construct string
    return "{},{},{},{}".format(
       top_left_x,
       top_left_y,
       bot_right_x,
       bot_right_y
    )

# Execute 'main()' function
if (__name__ == "__main__"):
    main(sys.argv)

