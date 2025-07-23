#!/bin/bash
#!/bin/bash

# Creates the directories for the models inside of the volume that is mounted from the host
echo "Creating directories for models..."
MODEL_DIRECTORIES=(
    "checkpoints"
    "clip"
    "clip_vision"
    "configs"
    "controlnet"
    "diffusers"
    "diffusion_models"
    "embeddings"
    "gligen"
    "hypernetworks"
    "loras"
    "photomaker"
    "style_models"
    "text_encoders"
    "unet"
    "upscale_models"
    "vae"
    "vae_approx"
)
for MODEL_DIRECTORY in ${MODEL_DIRECTORIES[@]}; do
    mkdir -p /opt/comfyui/models/$MODEL_DIRECTORY
done

# Creates the symlink for the ComfyUI Manager to the custom nodes directory, which is also mounted from the host
echo "Creating symlink for ComfyUI Manager..."
rm --force /opt/comfyui/custom_nodes/ComfyUI-Manager
ln -s \
    /opt/comfyui-manager \
    /opt/comfyui/custom_nodes/ComfyUI-Manager

# The custom nodes that were installed using the ComfyUI Manager may have requirements of their own, which are not installed when the container is
# started for the first time; this loops over all custom nodes and installs the requirements of each custom node
echo "Installing requirements for custom nodes..."
for CUSTOM_NODE_DIRECTORY in /opt/comfyui/custom_nodes/*;
do
    if [ "$CUSTOM_NODE_DIRECTORY" != "/opt/comfyui/custom_nodes/ComfyUI-Manager" ] && [ "$CUSTOM_NODE_DIRECTORY" != "/opt/comfyui/custom_nodes/ComfyScript" ];
    then
        if [ -f "$CUSTOM_NODE_DIRECTORY/requirements.txt" ];
        then
            CUSTOM_NODE_NAME=${CUSTOM_NODE_DIRECTORY##*/}
            CUSTOM_NODE_NAME=${CUSTOM_NODE_NAME//[-_]/ }
            echo "Installing requirements for $CUSTOM_NODE_NAME..."
            pip install --requirement "$CUSTOM_NODE_DIRECTORY/requirements.txt"
        fi
    fi
done

# --- PRE-START LOGIC ---
echo "[wrapper] Checking for ComfyScript node..."

ORIGINAL_DIR="$(pwd)"

# Clone only if it doesn't exist
if [ ! -d "/opt/comfyui/custom_nodes/ComfyScript" ]; then
    echo "[entry.sh] Cloning ComfyScript..."
    git clone https://github.com/Chaoses-Ib/ComfyScript.git /opt/comfyui/custom_nodes/ComfyScript
else
    echo "[entry.sh] ComfyScript directory already exists."
fi

# Check if comfy_script module is available
if ! python -c "import comfy_script" &>/dev/null; then
    echo "[entry.sh] comfy_script module not found, installing..."
    cd /opt/comfyui/custom_nodes/ComfyScript
    python -m pip install -e ".[default]"
    cd "$ORIGINAL_DIR"
else
    echo "[entry.sh] comfy_script module already available, skipping install."
fi


# Check if the 'comfy' module is installed
echo "[wrapper] Checking if 'comfy' Python package is installed..."
if python -c "import comfy" &> /dev/null; then
    echo "[wrapper] 'comfy' package is installed."
else
    echo "[wrapper] ERROR: 'comfy' package is NOT installed."
    # Optional: exit with error or install it
    # exit 1
fi

# Under normal circumstances, the container would be run as the root user, which is not ideal, because the files that are created by the container in
# the volumes mounted from the host, i.e., custom nodes and models downloaded by the ComfyUI Manager, are owned by the root user; the user can specify
# the user ID and group ID of the host user as environment variables when starting the container; if these environment variables are set, a non-root
# user with the specified user ID and group ID is created, and the container is run as this user
if [ -z "$USER_ID" ] || [ -z "$GROUP_ID" ];
then
    echo "Running container as $USER..."
    exec "$@"
else
    echo "[entry.sh] Creating non-root user..."

    # DEBUG: Print variable values
    echo "[entry.sh] GROUP_ID: '${GROUP_ID}'"
    echo "[entry.sh] USER_ID: '${USER_ID}'"

    # Check if GROUP_ID and USER_ID are set
    if [[ -z "$GROUP_ID" ]]; then
        echo "[entry.sh] ERROR: GROUP_ID is not set."
        exit 1
    fi

    if [[ -z "$USER_ID" ]]; then
        echo "[entry.sh] ERROR: USER_ID is not set."
        exit 1
    fi

    # Create group if it doesn't exist
    if getent group "$GROUP_ID" > /dev/null 2>&1; then
        echo "[entry.sh] Group $GROUP_ID already exists."
    else
        echo "[entry.sh] Creating group comfyui-user with GID $GROUP_ID..."
        groupadd --gid "$GROUP_ID" comfyui-user
    fi

    # Create user if it doesn't exist
    if id -u "$USER_ID" > /dev/null 2>&1; then
        echo "[entry.sh] User $USER_ID already exists."
    else
        echo "[entry.sh] Creating user comfyui-user with UID $USER_ID and GID $GROUP_ID..."
        useradd --uid "$USER_ID" --gid "$GROUP_ID" --create-home comfyui-user
    fi

    for DIR in /opt/comfyui /opt/comfyui-manager /opt/code-server; do
        CURRENT_UID=$(stat -c "%u" "$DIR")
        CURRENT_GID=$(stat -c "%g" "$DIR")

        if [ "$CURRENT_UID" -eq "$USER_ID" ] && [ "$CURRENT_GID" -eq "$GROUP_ID" ]; then
            echo "[entry.sh] Ownership of $DIR is already correct. Skipping chown."
        else
            echo "[entry.sh] Changing ownership of $DIR to $USER_ID:$GROUP_ID..."
            chown --recursive "$USER_ID:$GROUP_ID" "$DIR"
        fi
    done

    # Define extensions
    EXTENSIONS=(
    ms-python.python
    thenestruo.dark-minus-theme
    ms-toolsai.jupyter
    )

    # Loop through each extension and install only if not present
    for EXT in "${EXTENSIONS[@]}"; do
    if sudo --set-home --preserve-env=PATH --user "#$USER_ID" code-server --list-extensions | grep -q "^$EXT$"; then
        echo "[entry.sh] Extension '$EXT' already installed, skipping."
    else
        echo "[entry.sh] Installing extension '$EXT'..."
        sudo --set-home --preserve-env=PATH --user "#$USER_ID" code-server --install-extension "$EXT"
    fi
    done

    export PATH=$PATH:/home/comfyui-user/.local/bin
    echo "[entry.sh] PATH: $PATH"

    echo "[entry.sh] Running container as user ID $USER_ID..."
    sudo --set-home --preserve-env=PATH --preserve-env=PASSWORD --user "#$USER_ID" "$@"
fi

