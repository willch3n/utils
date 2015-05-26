#!/bin/bash

################################################################################
# Description:
#    * Checks whether an ssh-agent is running; if not, starts a new one
#    * Checks whether any keys have been added; if none, adds '~/.ssh/id_rsa' or '~/.ssh/id_dsa'
#    * Must be sourced, not executed, for environment variables to be set in current shell
################################################################################


# Constants
ssh_agent_env=~/.ssh/agent.env;  # Path to output from 'ssh-agent' for setting environment variables


# Returns whether an ssh-agent is running
check_ssh_agent_running() {
   if [[ "$SSH_AUTH_SOCK" ]]; then  # Environment variables set, so it's possible that an agent is already running
      ssh-add -l &> /dev/null;
      if [[ $? -ne 2 ]]; then true;  # '2' indicates that no ssh-agent is running
      else false;
      fi
   else  # Environment variables not set, so no ssh-agent is running
      false;
   fi
}

# Returns whether any keys have been added
check_key_added() {
   ssh-add -l &> /dev/null;
   if [[ $? -eq 0 ]]; then true;  # '0' indicates that ssh-agent is running and has keys
   else false;
   fi
}

# Load environment variables from previous start of ssh-agent in a different terminal/environment, if any
if [[ -e $ssh_agent_env ]]; then  # File exists
   echo "Setting ssh-agent environment variables stored in '$ssh_agent_env'...";
   . "$ssh_agent_env";   # Set environment variables so that 'ssh-add' can communicate with any already-running agents
fi

# Check whether an ssh-agent is running; if not, start a new one
if ! check_ssh_agent_running; then
   echo "No ssh-agent running; starting new ssh-agent...";
   ssh-agent -s > "$ssh_agent_env";  # Start ssh-agent and write its output for setting environment variables to file
   . "$ssh_agent_env";               # Set environment variables using that file
   if ! check_ssh_agent_running; then  # Still not running
      echo "Error: Failed to start ssh-agent!";
      exit;
   fi
else
   echo "ssh-agent is already running";
fi

# Check whether any keys have been added; if none, add '~/.ssh/id_rsa' or '~/.ssh/id_dsa'
if ! check_key_added; then
   echo "Adding key...";
   ssh-add;
else
   echo "ssh-agent already has keys";
fi

