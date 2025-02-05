#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    EXECUTABLE="./Builds/BuildServer/ExfilPoint"
else
    # Linux
    EXECUTABLE="./Builds/BuildServer"
fi

# Set executable permission if needed
chmod +x "$EXECUTABLE"

# Start the server in headless mode with port 7770
"$EXECUTABLE" -batchmode -nographics -server -port 7770 -logfile server.log 