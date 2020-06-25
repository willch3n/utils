#!/usr/bin/env python3

################################################################################
# Description:
#    * Displays a grid of RTSP streams from IP cameras
#    * Outputs to display attached to HDMI port of Raspberry Pi
#    * Requires that 'omxplayer' video player is available
#    * Expects a configuration file in home directory named '.ip_cam_viewer_cfg.json', in the following format:
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
bin_paths = {"screen"   : "/usr/bin/screen",
             "grep"     : "/bin/grep",
             "omxplayer": "/usr/bin/omxplayer"}
cfg_file_path = "~/.ip_cam_viewer_cfg.json"
player_opts = "--avdict rtsp_transport:tcp --live -n -1"
scr_sess_prefix = "ip_cam"
disp_res_x = 1920
disp_res_y = 1080
grid_sz_x = 2
grid_sz_y = 2

# Main function
def main(argv):
   # Configure argument parser
   desc_str = "Displays a grid of RTSP streams from IP cameras,"
   desc_str += " outputting to display attached to HDMI port of Raspberry Pi."
   parser = argparse.ArgumentParser(description=desc_str)
   parser.add_argument("action", choices=["start", "repair", "stop"], help="Action to take")
   parser.add_argument("--dry", action="store_true", help="Assembles and prints commands without executing them")

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
   global cfg_file_path
   cfg_file_path = os.path.expanduser(cfg_file_path)
   cfg_file_path = os.path.expandvars(cfg_file_path)
   print("Parsing configuration file '{}'...".format(cfg_file_path))
   cfg = json.load(open(cfg_file_path))
   check_cfg_file(cfg)  # Check that configuration file contained all required information
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

   if (shutil.which(bin_paths["omxplayer"], mode=os.X_OK)):
      print("'{}' executable found.".format(bin_paths["omxplayer"]))
      print("")
   else:
      msg = "'{}' executable not found.  Verify that device is a".format(bin_paths["omxplayer"])
      msg += " Raspberry Pi, and that '{}' video player is installed.".format(bin_paths["omxplayer"])
      raise Exception(msg)

# Checks that configuration file contained all required information
def check_cfg_file(cfg):
   # Streams
   if ("streams" in cfg):
      if (len(cfg["streams"]) > 0):  # Parsed 'streams[]' list contains at least one item
         print("Parsed {} streams from configuration file:".format(len(cfg["streams"])))
         for stream in cfg["streams"]:
            if ("uri" in stream):  # 'uri' element found for stream
               print("   * {}: {}".format(stream["name"], stream["uri"]))
            else:  # No 'uri' element found for stream
               msg = "No 'uri' element found for stream '{}'".format(stream["name"])
               raise Exception(msg)
      else:  # Parsed 'streams[]' list is empty
         msg = "Configuration file 'streams[]' list is empty."
         raise Exception(msg)
   else:  # No 'streams[]' list found
      msg = "Configuration file does not contain a 'streams[]' list."
      raise Exception(msg)

# Starts streams, skipping any that are already running
def start_streams(cfg, live_run):
   print("Starting streams...")

   for (idx, stream) in enumerate(cfg["streams"]):
      # If screen session for this index already exists, let it carry on
      if (check_screen_session_exists(idx)):
         print("Screen session '{}_{}' already exists; skipping.".format(scr_sess_prefix, idx))
         continue

      # Otherwise, assemble and execute start command
      start_cmd = "{} {}".format(bin_paths["omxplayer"], player_opts)
      start_cmd += " --win {}".format(win_pos(idx % grid_sz_x, idx // grid_sz_x))
      start_cmd += " {}".format(stream["uri"])
      start_cmd = "{} -dmS {}_{} bash -c '{}'".format(bin_paths["screen"], scr_sess_prefix, idx, start_cmd)
      print(start_cmd)
      if (live_run):
         exit_status = os.system(start_cmd)
         if (exit_status != 0):
            msg = "Command '{}' failed with error code {}.".format(start_cmd, exit_status)
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
         print("Screen session '{}_{}' already stopped; skipping.".format(scr_sess_prefix, idx))
         continue

      # Otherwise, stop it
      stop_cmd = "{} -S {}_{} -X quit".format(bin_paths["screen"], scr_sess_prefix, idx)
      print(stop_cmd)
      if (live_run):
         exit_status = os.system(stop_cmd)
         if (exit_status != 0):
            msg = "Command '{}' failed with error code {}.".format(stop_cmd, exit_status)
            raise Exception(msg)

   print("")

# Checks whether a screen session of the given index is already running
def check_screen_session_exists(session_idx):
   # Check that 'grep' is available
   if (not shutil.which(bin_paths["grep"], mode=os.X_OK)):
      msg = "'{}' executable not found.".format(bin_paths["grep"])
      raise Exception(msg)

   # List active screen sessions and search through it
   check_cmd = "{} -list | {} '\.{}_{}\s'".format(bin_paths["screen"], bin_paths["grep"], scr_sess_prefix, session_idx)
   return (os.system(check_cmd) == 0)

# Given grid coordinates, computes the pixel coordinates of the corresponding
# bounding box, in a string to be provided to 'omxplayer' via its '--win'
# option
def win_pos(x, y):
   # Compute X and Y sizes of each stream
   x_sz = int(disp_res_x / grid_sz_x)
   y_sz = int(disp_res_y / grid_sz_y)

   # Compute pixel coordinates of top-left and bottom-right corners of bounding
   # box
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

