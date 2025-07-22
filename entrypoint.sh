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

CUSTOM_NODE_DIR="/opt/comfyui/custom_nodes/ComfyScript"

if [ ! -d "$CUSTOM_NODE_DIR" ]; then
  echo "[wrapper] Cloning ComfyScript..."
  git clone https://github.com/Chaoses-Ib/ComfyScript.git "$CUSTOM_NODE_DIR"

  echo "[wrapper] Installing ComfyScript in editable mode..."
  python -m pip install -e "$CUSTOM_NODE_DIR\[default]"
else
  echo "[wrapper] ComfyScript already exists, skipping clone."
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
    echo "Creating non-root user..."

    echo "Checking if group $GROUP_ID exists..."
    if getent group "$GROUP_ID" > /dev/null 2>&1; then
        echo "Group $GROUP_ID already exists."
    else
        echo "Group $GROUP_ID does not exist. Creating group $USER_NAME with GID $GROUP_ID..."
        groupadd --gid "$GROUP_ID" "$USER_NAME" || { echo "Failed to create group."; exit 1; }
    fi

    echo "Checking if user $USER_ID exists..."
    if id -u "$USER_ID" > /dev/null 2>&1; then
        echo "User $USER_ID already exists."
    else
        echo "User $USER_ID does not exist. Creating user $USER_NAME with UID $USER_ID..."
        useradd --uid "$USER_ID" --gid "$GROUP_ID" --create-home "$USER_NAME" || { echo "Failed to create user."; exit 1; }
    fi

    echo "Changing ownership of /opt/comfyui to $USER_ID:$GROUP_ID..."
    chown --recursive "$USER_ID:$GROUP_ID" /opt/comfyui || { echo "chown failed on /opt/comfyui"; exit 1; }

    echo "Changing ownership of /opt/comfyui-manager to $USER_ID:$GROUP_ID..."
    chown --recursive "$USER_ID:$GROUP_ID" /opt/comfyui-manager || { echo "chown failed on /opt/comfyui-manager"; exit 1; }

    echo "Appending local bin to PATH for $USER_NAME..."
    export PATH="$PATH:/home/$USER_NAME/.local/bin"

    echo "Final PATH: $PATH"
    echo "Running container as $USER_NAME (UID: $USER_ID)..."
    exec sudo --set-home --preserve-env=PATH --user "#$USER_ID" "$@" || { echo "Failed to switch user."; exit 1; }
fi

