ARG ROS_DISTRO=humble
FROM ros:${ROS_DISTRO}-ros-base

ARG ROS_DISTRO
ENV ROS_DISTRO=${ROS_DISTRO}
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-c"]

# Install system dependencies & ROS 2 packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip \
    python3-dev \
    ros-${ROS_DISTRO}-cv-bridge \
    ros-${ROS_DISTRO}-std-msgs \
    ros-${ROS_DISTRO}-sensor-msgs \
    git \
    ffmpeg \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    && rm -rf /var/lib/apt/lists/*

# Install heavy PyTorch wheels FIRST before copying any project files so layer cache is never invalidated by code changes
RUN pip3 install --no-cache-dir torch torchvision --index-url https://download.pytorch.org/whl/cu128

# Runtime user matching the host user (uid/gid 1000) so FastDDS shared memory
# transport works between host processes and this container (ipc: host).
RUN groupadd -g 1000 ros && useradd -m -u 1000 -g 1000 -s /bin/bash ros

WORKDIR /app

# Copy requirements and install python packages
COPY requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Copy package source files
COPY . /app/ros2_ws/src/bob_mossimg

# Build ROS 2 workspace
WORKDIR /app/ros2_ws
RUN source /opt/ros/${ROS_DISTRO}/setup.bash && colcon build --packages-select bob_mossimg

WORKDIR /app

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["ros2", "run", "bob_mossimg", "tti", "--ros-args", "--params-file", "/app/ros2_ws/src/bob_mossimg/config/tti.yaml"]
