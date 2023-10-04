#!/usr/bin/env python3

################################################################################
# Description:
#    * Displays a grid of RTSP streams from IP cameras
#    * Outputs to display attached to HDMI port of Raspberry Pi
#    * Requires that following executables are available:
#       * tvservice: Raspberry Pi HDMI display utility
#       * omxplayer: Raspberry Pi GPU-accelerated video player
#       * vcgencmd:  Raspberry Pi VideoCore GPU query utility
#    * Expects a configuration file in home directory named
#      '.ip_cam_viewer_cfg.json', in the following format:
#      {
#         "streams": [
#            {"name": "cam_0_name", "uri": "rtsp://username:password@foo.bar.com:port/"},
#            {"name": "cam_1_name", "uri": "rtsp://username:password@foo.bar.com:port/", "transport": "udp"}
#         ]
#      }
#    * Transport protocol may be optionally specified per stream; if not
#      specified, defaults to TCP
#
# Arguments:
#    * action (required)
#       * start:   Starts streams, skipping any that are already running
#       * repair:  Restarts any stream with no corresponding DispmanX layer
#       * restart: Stops all streams, and then starts them anew
#       * stop:    Stops all streams
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
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time

# Constants
BIN_PATHS = {"screen"   : "/usr/bin/screen",
             "grep"     : "/bin/grep",
             "tvservice": "/usr/bin/tvservice",
             "omxplayer": "/usr/bin/omxplayer",
             "vcgencmd" : "/usr/bin/vcgencmd"}
CFG_FILE_PATH = "~/.ip_cam_viewer_cfg.json"
DEFAULT_TRANSPORT_PROTO = "tcp"
SCR_SESS_PREFIX = "cam"
FPS = 5

# Main function
def main(argv):
    # Configure argument parser
    desc_str = "Displays a grid of RTSP streams from IP cameras,"
    desc_str += " outputting to display attached to HDMI port of Raspberry Pi."
    parser = argparse.ArgumentParser(description=desc_str)
    parser.add_argument(
        "action",
        choices=["start", "repair", "restart", "stop"],
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

    # Check that required executables are available
    if (args.action in ["start", "repair", "restart"]):
        check_exe(BIN_PATHS["tvservice"])
        check_exe(BIN_PATHS["omxplayer"])
    if (args.action == "repair"):
        check_exe(BIN_PATHS["vcgencmd"])

    # Parse configuration file
    cfg_file_path = os.path.expanduser(CFG_FILE_PATH)
    cfg_file_path = os.path.expandvars(cfg_file_path)
    print("Parsing configuration file '{}'...".format(cfg_file_path))
    cfg = json.load(open(cfg_file_path))
    check_cfg_file(cfg)  # Check for completeness and validity of file
    print("")

    # Take requested action
    if   (args.action == "start"):   start_streams(cfg, not args.dry)
    elif (args.action == "repair"):  repair_streams(cfg, not args.dry)
    elif (args.action == "restart"): restart_streams(cfg, not args.dry)
    elif (args.action == "stop"):    stop_streams(cfg, not args.dry)

    # Exit
    print("Done.")
    print("")
    sys.exit(0)  # Success

# Checks that a given executable is available
def check_exe(exe_path):
    print("Checking that '{}' executable is available...".format(exe_path))

    if (shutil.which(exe_path, mode=os.X_OK)):
        print("'{}' executable found.".format(exe_path))
        print("")
    else:
        msg = "'{}' executable not found.  ".format(exe_path)
        msg += "Verify that device is a Raspberry Pi, and that "
        msg += "'{}' is installed.".format(exe_path)
        raise Exception(msg)

# Checks for completeness and validity of configuration file
def check_cfg_file(cfg):
    # Streams
    if ("streams" in cfg):
        if (len(cfg["streams"]) > 0):  # Parsed list contains at least one item
            msg = "Parsed {} streams ".format(len(cfg["streams"]))
            msg += "from configuration file:"
            print(msg)
            for stream in cfg["streams"]:
                if ("uri" in stream):  # 'uri' element found for stream
                    msg = "   * {}: {}".format(stream["name"], stream["uri"])

                    # Validate transport protocol, if specified
                    if "transport" in stream:  # Key-value pair specified
                        transport_proto = stream["transport"]
                        if transport_proto in ["tcp", "udp"]:  # Valid protocol
                            msg += " ({})".format(transport_proto.upper())
                        else:  # Invalid transport protocol specification
                            msg = "Invalid transport protocol "
                            msg += "'{}' specified ".format(transport_proto)
                            msg += "for stream '{}'; ".format(stream["name"])
                            msg += "valid values are 'tcp' and 'udp'."
                            raise Exception(msg)

                    print(msg)
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
    # Compute dimensions of grid according to number of streams to be displayed
    (grid_sz_x, grid_sz_y) = calc_grid_dims(cfg)

    # Start streams
    print("Starting streams...")
    for (idx, stream) in enumerate(cfg["streams"]):
        # If screen session for this index already exists, let it carry on
        if (check_screen_session_exists(idx)):
            msg = "Screen session '{}{}' ".format(SCR_SESS_PREFIX, idx)
            msg += "already exists; skipping."
            print(msg)
            continue

        # Select transport protocol
        if "transport" in stream:  # Key-value pair specified
            transport_proto = stream["transport"]
        else:  # Key-value pair not specified
            transport_proto = DEFAULT_TRANSPORT_PROTO

        # Otherwise, assemble and execute start command
        bounding_box_coords = win_pos(
            grid_sz_x,  # Width of grid
            grid_sz_y,  # Height of grid
            idx % grid_sz_x,  # X coordinate of current stream
            idx // grid_sz_x,  # Y coordinate of current stream
        )
        win_pos_str = ",".join(str(c) for c in bounding_box_coords)
        start_cmd = "{}".format(BIN_PATHS["omxplayer"])
        start_cmd += " --avdict rtsp_transport:{}".format(transport_proto)
        start_cmd += " --live"
        start_cmd += " -n -1"  # No audio
        start_cmd += " --win {}".format(win_pos_str)
        start_cmd += " --fps {}".format(FPS)
        start_cmd += " {}".format(stream["uri"])
        start_cmd = "{} -dmS {}{} bash -c '{}'".format(
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

# Terminates and then restarts any stream with no corresponding DispmanX layer
def repair_streams(cfg, live_run):
    dispmanx_coords = []

    # Query VideoCore GPU utility to obtain pixel coordinates of top-left
    # corner of each active DispmanX layer
    vcgencmd_proc = subprocess.run(
        [BIN_PATHS["vcgencmd"], "dispmanx_list"],
        capture_output=True,
        text=True,
    )
    for line in vcgencmd_proc.stdout.splitlines():
        if re.search(r"format:UNKNOWN", line):
            continue  # Ignore unknown layer
        m = re.search(r"display:\d+ format:\S+ .*dst:(\d+,\d+),\d+,\d+ ", line)
        if m:  # Matched line for a valid and active layer
            dispmanx_coords.append(m.group(1))  # Record coordinates of corner

    # Compute dimensions of grid according to number of streams to be displayed
    (grid_sz_x, grid_sz_y) = calc_grid_dims(cfg)

    # Repair streams
    print("Repairing streams...")
    missing_stream_cnt = 0
    for (idx, _) in enumerate(cfg["streams"]):
        # Construct string containing expected pixel coordinates of top-left
        # corner of stream
        bounding_box_coords = win_pos(
            grid_sz_x,  # Width of grid
            grid_sz_y,  # Height of grid
            idx % grid_sz_x,  # X coordinate of current stream
            idx // grid_sz_x,  # Y coordinate of current stream
        )
        win_pos_str = ",".join(str(c) for c in bounding_box_coords[0:2])

        # If no active DispmanX layer with matching coordinates, stop
        # corresponding screen session, if any
        if (win_pos_str not in dispmanx_coords):
            missing_stream_cnt += 1
            stop_cmd = "{} -S {}{} -X quit".format(
                BIN_PATHS["screen"],
                SCR_SESS_PREFIX,
                idx,
            )
            print(stop_cmd)
            if (live_run):
                os.system(stop_cmd)
    print("")

    # Restart missing streams, if any
    if (missing_stream_cnt > 0):  # At least one stream to restart
        start_streams(cfg, live_run)
        print("Repaired {} stream(s).".format(missing_stream_cnt))
    else:  # No missing streams
        print("All streams intact; no action required.")

    print("")

# Stops all streams, and then starts them anew
def restart_streams(cfg, live_run):
    print("Restarting streams...")
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
            msg = "Screen session '{}{}' ".format(SCR_SESS_PREFIX, idx)
            msg += "already stopped; skipping."
            print(msg)
            continue

        # Otherwise, stop it
        stop_cmd = "{} -S {}{} -X quit".format(
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
    check_cmd = "{} -list | {} '\.{}{}\s'".format(
        BIN_PATHS["screen"],
        BIN_PATHS["grep"],
        SCR_SESS_PREFIX,
        session_idx
    )
    return (os.system(check_cmd) == 0)

# Computes dimensions of grid according to number of streams to be displayed
def calc_grid_dims(cfg):
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

    return (grid_sz_x, grid_sz_y)

# Given grid dimensions and coordinates, computes the pixel coordinates of the
# corresponding bounding box and returns them in a 4-element list
def win_pos(grid_sz_x, grid_sz_y, x, y):
    # Query HDMI display utility to obtain resolution of current display
    disp_res_x = None
    disp_res_y = None
    tvservice_proc = subprocess.run(
        [BIN_PATHS["tvservice"], "--status"],
        capture_output=True,
        text=True,
    )
    for line in tvservice_proc.stdout.splitlines():
        m = re.search(r"^state .*, (\d+)x(\d+) @ \d+\.\d+Hz, ", line)
        if m:  # Matched line containing current mode, resolution, frequency
            disp_res_x = int(m.group(1))
            disp_res_y = int(m.group(2))
    if (not disp_res_x) or (not disp_res_y):
        msg = "Failed to query 'tvservice' HDMI display utility to obtain "
        msg += "resolution of current display"
        raise Exception(msg)

    # Compute X and Y sizes of each stream
    x_sz = int(disp_res_x / grid_sz_x)
    y_sz = int(disp_res_y / grid_sz_y)

    # Compute pixel coordinates of top-left and bottom-right corners of
    # bounding box
    top_left_x = x * x_sz
    top_left_y = y * y_sz
    bot_right_x = top_left_x + x_sz
    bot_right_y = top_left_y + y_sz

    # Construct and return list containing bounding box coordinates
    return [
        top_left_x,  top_left_y,
        bot_right_x, bot_right_y,
    ]

# Execute 'main()' function
if (__name__ == "__main__"):
    main(sys.argv)

