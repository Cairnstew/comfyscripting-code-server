# Stage 1: Build your code-server image
FROM ghcr.io/lecode-official/comfyui-docker:latest

# --- Environment Variables ---
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    CODE_SERVER_PORT=8080 \
    EXT_SCRIPT_DIR=/opt/scripts

# --- Install Base Dependencies ---
RUN apt-get update && \
    apt-get install -y \
        curl gnupg ca-certificates jq build-essential \
        libssl-dev libffi-dev git wget unzip sudo && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# --- Install code-server ---
RUN curl -fsSL https://code-server.dev/install.sh | sh

# Ensure the working directory is set (will create if it doesn't exist)
WORKDIR /opt/code-server

# --- Download Extensions ---
RUN code-server --install-extension ms-python.python
RUN code-server --install-extension thenestruo.dark-minus-theme
RUN code-server --install-extension ms-toolsai.jupyter

# --- Expose Port ---
EXPOSE ${CODE_SERVER_PORT}

WORKDIR /opt/comfyui

# Copy the script into the working directory
COPY start-comfyui.sh ./start-comfyui.sh

# Make it executable
RUN chmod +x ./start-comfyui.sh

# Expose the necessary ports
EXPOSE 8188
EXPOSE 8080

# Copy the entrypoint script to root and make it executable
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

CMD code-server --bind-addr 0.0.0.0:8080 --auth password