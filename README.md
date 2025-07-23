# ComfyScripting Code Server

This repository provides a Docker-based development environment optimized for scripting with [ComfyScript](https://github.com/Chaoses-Ib/ComfyScript) within [ComfyUI](https://github.com/comfyanonymous/ComfyUI), alongside [code-server](https://github.com/coder/code-server) for a web-based Visual Studio Code experience. The setup supports GPU acceleration and includes ComfyUI Manager for managing custom nodes.

## Features
- **ComfyScript**: A custom node for advanced scripting within ComfyUI.
- **ComfyUI**: A modular UI for Stable Diffusion workflows (must be started manually).
- **code-server**: A browser-based VS Code environment for coding and scripting.
- **GPU Support**: Configured for NVIDIA GPUs using CDI (Container Device Interface).
- **Custom Nodes and Models**: Persistent storage via Docker volumes.
- **Pre-installed Extensions**: Includes Python, Jupyter, and Dark Minus Theme for code-server.

## Prerequisites
- [Docker](https://www.docker.com/get-started) and [Docker Compose](https://docs.docker.com/compose/install/) installed.
- NVIDIA GPU with compatible drivers and CDI support for GPU acceleration (optional).
- A `.env` file configured with environment variables.

## Getting Started

### 1. Clone the Repository
```bash
git clone https://github.com/Cairnstew/comfyscripting-code-server.git
cd comfyscripting-code-server
```

### 2. Set Up Environment Variables
Copy the example `.env` file and edit it:
```bash
cp .env.example .env
```
Edit `.env` to include:
```bash
PASSWORD=your_secure_password
USER_ID=1000
GROUP_ID=1000
USER_NAME=my_user
```
Replace `your_secure_password` with a strong password for code-server access.

### 3. Build and Run
Build and start the Docker container:
```bash
docker-compose up -d
```

### 4. Access code-server
- **code-server**: Available at `http://localhost:8080` (use the password from `.env`).

### 5. Start ComfyUI Manually
To start ComfyUI, access the container's bash shell:
```bash
docker exec -it comfy-code-dev bash
```
Then run:
```bash
cd /opt/comfyui && bash start-comfyui.sh
```
ComfyUI will be available at `http://localhost:8188`.

## Key Files
- `docker-compose.yaml`: Defines the Docker service configuration.
- `Dockerfile`: Builds the image with ComfyUI, code-server, and ComfyScript.
- `entrypoint.sh`: Initializes model directories, symlinks ComfyUI Manager, installs custom node requirements, and sets up a non-root user.
- `start-comfyui.sh`: Script to manually start ComfyUI, located in `/opt/comfyui`.
- `.env.example`: Template for environment variables.

## Customization
- **Custom Nodes**: Add nodes to `./custom_nodes`. Requirements are installed if a `requirements.txt` is present.
- **Models**: Place models in subdirectories under `./models` (e.g., `checkpoints`, `loras`).

## Notes
- ComfyUI must be started manually via `start-comfyui.sh` inside the container.
- The container runs as a non-root user if `USER_ID` and `GROUP_ID` are specified in `.env`, ensuring proper file ownership.
- The `code-server-data` volume persists data across container restarts.


## License
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
