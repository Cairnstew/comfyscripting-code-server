#!/bin/bash

# Path to the Python executable
PYTHON_EXEC="/opt/conda/bin/python"

# Command to start ComfyUI
COMFYUI_CMD="$PYTHON_EXEC main.py --listen 0.0.0.0 --port 8188 --disable-auto-launch"

# Check if the Python executable exists
if [ ! -f "$PYTHON_EXEC" ]; then
    echo "Error: Python executable not found at $PYTHON_EXEC"
    exit 1
fi

# Run the ComfyUI command
echo "Starting ComfyUI..."
$COMFYUI_CMD

# Check if the command executed successfully
if [ $? -eq 0 ]; then
    echo "ComfyUI started successfully."
else
    echo "Error: Failed to start ComfyUI."
    exit 1
fi