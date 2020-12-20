#!/usr/bin/python

###############################################################################
# Description:
#    * Takes a single snapshot from attached camera at full resolution
#    * Requires attached Raspberry Pi camera module
#
# Arguments:
#    * None
#
# Examples:
#    * ./rpi_cam_capture.py
#
# Limitations:
#    * Tested on only Raspberry Pi 3 Model B
###############################################################################

# Modules
import sys
import time
from picamera import PiCamera

# Constants
RES_X = 2592  # Maximum
RES_Y = 1944  # Maximum
ROTATION = 180  # Camera is inverted
FRAMERATE = 15
SLEEP_DURATION_SEC = 5  # Allow time for brightness adaptation

def main(argv):
    """
    Main function.
    """

    # Print current time
    print(time.strftime("%a %Y-%m-%d %I:%M:%S %p"))
    print("")

    # Take single snapshot, and then immediately release resources
    pi_camera = PiCamera()
    capture(pi_camera)
    pi_camera.close()

    # Exit
    print("Done.")
    print("")
    sys.exit(0)  # Success

def capture(pi_camera):
    """
    Take a snapshot and save it to current directory.
    """

    # Configuration
    print("Resolution: {} x {}".format(RES_X, RES_Y))
    print("Rotation: {}".format(ROTATION))
    print("Frame rate: {}".format(FRAMERATE))
    pi_camera.resolution = (RES_X, RES_Y)
    pi_camera.rotation = ROTATION
    pi_camera.framerate = FRAMERATE

    # Capture
    file_name = time.strftime("%Y-%m-%d_%H%M.jpg")
    print("Capturing 1 still frame and saving it to file '{}'...".format(file_name))
    pi_camera.start_preview()
    time.sleep(SLEEP_DURATION_SEC)
    pi_camera.capture(file_name)
    pi_camera.stop_preview()

# Execute 'main()' function
if (__name__ == "__main__"):
   main(sys.argv)

