#!/bin/bash

# Ensure the script is run as root
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

add_user_to_docker_group() {
    grep -E '^docker:' /usr/lib/group | tee -a /etc/group > /dev/null && usermod -aG docker $SUDO_USER
    echo "User added to the docker group. Please reboot the system to apply changes."
    read -p "Press Enter to reboot or CTRL+C to cancel..."
    reboot
}

ask_enable_docker_service() {
    echo "Would you like to start and enable Docker? [y/N]"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        systemctl start docker
        systemctl enable docker
        echo "Docker service started and enabled."
    else
        echo "Skipping Docker service start and enable."
    fi
}


# Check if Docker is installed
if command -v docker &> /dev/null; then
    echo "Docker is already installed. Proceeding to add user to Docker group..."
    add_user_to_docker_group
    ask_enable_docker_service
else
    # Add Docker CE repository
    cat <<EOF > /etc/yum.repos.d/docker.repo
[docker-ce-stable]
name=Docker CE Stable - \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/\$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg

[docker-ce-stable-debuginfo]
name=Docker CE Stable - Debuginfo \$basearch
baseurl=https://download.docker.com/linux/fedora/\$releasever/debug-\$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg

[docker-ce-stable-source]
name=Docker CE Stable - Sources
baseurl=https://download.docker.com/linux/fedora/\$releasever/source/stable
enabled=0
gpgcheck=1
gpgkey=https://download.docker.com/linux/fedora/gpg
EOF

    # Install Docker packages
    rpm-ostree install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo "Docker packages installed. The system will now reboot to apply changes."
    read -p "Press Enter to continue with the reboot or CTRL+C to cancel..."
    reboot

    # After reboot, the script needs to be run again manually to add the user to the Docker group.
fi
