#!/usr/bin/env python3

################################################################################
# Description:
#    * Parses names of files in directory containing snapshots of solar
#      suitcase displays, and formats them for pasting into timestamp column of
#      solar energy log spreadsheet
#    * Requires that Box WebDAV mount is active
#    * Expects a configuration file in home directory named
#      '.solar_snapshot_name_parse_cfg.json', in the following format:
#      {
#          "snapshot_dir": "/mnt/box_webdav/.../Solar charge logs"
#      }
#
# Arguments:
#    * --help (optional)
#      Displays help message
#
# Examples:
#    * ./solar_snapshot_name_parse.py
#    * ./solar_snapshot_name_parse.py --help
#
# Limitations:
#    * Tested on only Raspbian
#    * Makes no attempt to verify that Box WebDAV mount is valid
################################################################################


# Modules
import sys
import os
import time
import argparse
import json
import re

# Constants
CFG_FILE_PATH = "~/.solar_snapshot_name_parse_cfg.json"

# Main function
def main(argv):
    # Configure argument parser
    desc_str = "Parses names of files in directory containing snapshots of "
    desc_str += "solar suitcase displays, and formats them for pasting into "
    desc_str += "timestamp column of solar energy log spreadsheet"
    parser = argparse.ArgumentParser(description=desc_str)

    # Print current time
    print(time.strftime("%a %Y-%m-%d %I:%M:%S %p"))
    print("")

    # Parse arguments
    print("Parsing arguments...")
    args = parser.parse_args()
    for (arg, val) in sorted(vars(args).items()):
        print("   * {}: {}".format(arg, val))
    print("")

    # Parse configuration file
    cfg_file_path = os.path.expanduser(CFG_FILE_PATH)
    cfg_file_path = os.path.expandvars(cfg_file_path)
    print("Parsing configuration file '{}'...".format(cfg_file_path))
    cfg = json.load(open(cfg_file_path))
    check_cfg_file(cfg)  # Check that file contains all required information
    print("")

    # Retrieve names of files in snapshot directory
    print("Retrieving names of files in '{}'...".format(cfg["snapshot_dir"]))
    file_names = os.listdir(cfg["snapshot_dir"])

    # Format file names and print results
    print("Formatting file names and print results...")
    count = fmt_print_file_names(sorted(file_names))
    print("")

    # Exit
    print("Printed {} lines.".format(count))
    print("Done.")
    print("")
    sys.exit(0)  # Success

# Checks that configuration file contained all required information
def check_cfg_file(cfg):
    # Snapshot directory
    if ("snapshot_dir" in cfg):
        msg = "Parsed snapshot directory name from configuration file: "
        msg += "{}".format(cfg["snapshot_dir"])
        print(msg)
    else:  # No snapshot directory parsed
        msg = "Configuration file does not contain 'snapshot_dir' string."
        raise Exception(msg)

# Formats file names and prints results
def fmt_print_file_names(file_names):
    re_file_name = re.compile(r'^(\d{4}-\d{2}-\d{2})_(\d{2})(\d{2})_c(\d{2})\.jpg$')

    num_printed = 0
    for file_name in file_names:
        m = re_file_name.match(file_name)
        if m:  # Regular expression match
            m_date = m.group(1)
            m_hour = m.group(2)
            m_minute = m.group(3)
            m_contrast = m.group(4)

            if (m_contrast == "00"):  # Ignore duplicates
                print("{} {}:{}".format(m_date, m_hour, m_minute))
                num_printed += 1

    return num_printed

# Execute 'main()' function
if (__name__ == "__main__"):
    main(sys.argv)

