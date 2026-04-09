#!/bin/bash
# =============================================
#  CloudOps — EC2 Setup Script
#  Installs Docker + Jenkins on Ubuntu 22.04
#  Project: static-website-aws
#
#  HOW TO USE:
#  1. SSH into your EC2:  ssh -i key.pem ubuntu@YOUR_EC2_IP
#  2. Copy this file to EC2 or paste the contents directly
#  3. Make it executable:  chmod +x setup-ec2.sh
#  4. Run it:              sudo ./setup-ec2.sh
# =============================================

# Exit immediately if any command fails
# This prevents the script from continuing after an error
set -e

# Print each command before running it (great for debugging)
set -x

echo "============================================="
echo "  CloudOps EC2 Setup — Starting Installation"
echo "============================================="


# ─────────────────────────────────────────────
# SECTION 1: SYSTEM UPDATE
# Always update first so you get the latest
# security patches and package lists
# ─────────────────────────────────────────────
echo ""
echo ">>> [1/7] Updating system packages..."

# apt-get update  = refresh the list of available packages from Ubuntu's servers
# apt-get upgrade = actually install the newer versions of existing packages
# -y              = answer "yes" automatically to all prompts (non-interactive)
sudo apt-get update -y
sudo apt-get upgrade -y

echo ">>> System packages updated."


# ─────────────────────────────────────────────
# SECTION 2: INSTALL REQUIRED TOOLS
# These are helper tools needed before we can
# install Docker and Jenkins
# ─────────────────────────────────────────────
echo ""
echo ">>> [2/7] Installing required dependencies..."

sudo apt-get install -y \
  curl \          # Used to download files from the internet
  wget \          # Another download tool (Jenkins uses this)
  gnupg \         # GNU Privacy Guard — used to verify package signatures
  ca-certificates \  # SSL certificates so HTTPS downloads work
  lsb-release \   # Prints the Ubuntu version name (e.g. "jammy" for 22.04)
  apt-transport-https \  # Lets apt download packages over HTTPS
  software-properties-common  # Lets us add external package repositories

echo ">>> Dependencies installed."


# ─────────────────────────────────────────────
# SECTION 3: INSTALL DOCKER
# We install Docker from Docker's own official
# repository — NOT Ubuntu's built-in version
# (Ubuntu's version is often outdated)
# ─────────────────────────────────────────────
echo ""
echo ">>> [3/7] Installing Docker..."

# Step 3a: Add Docker's official GPG signing key
# This key proves the Docker packages you download are genuine and not tampered with
# "gpg --dearmor" converts the key from text format to binary format
# The key is saved to /etc/apt/keyrings/docker.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Step 3b: Add Docker's package repository to Ubuntu's package sources
# This tells Ubuntu: "also look for packages in Docker's official repo"
# $(lsb_release -cs) automatically inserts your Ubuntu codename e.g. "jammy"
# $(dpkg --print-architecture) inserts your CPU architecture e.g. "amd64"
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Step 3c: Refresh package list now that Docker's repo is added
sudo apt-get update -y

# Step 3d: Install Docker engine and its components
# docker-ce                  = Docker Community Edition (the main engine)
# docker-ce-cli              = The "docker" command you type in terminal
# containerd.io              = The container runtime Docker uses under the hood
# docker-buildx-plugin       = Lets you build multi-platform images
# docker-compose-plugin      = Lets you use "docker compose" command
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

# Step 3e: Start Docker now and enable it to start automatically on server reboot
# start   = turn Docker on right now
# enable  = make Docker start automatically every time the server boots up
sudo systemctl start docker
sudo systemctl enable docker

# Step 3f: Add the "ubuntu" user to the "docker" group
# By default, only root can run Docker commands
# Adding ubuntu to the docker group lets it run docker WITHOUT sudo
# (You need to log out and back in for this to take effect)
sudo usermod -aG docker ubuntu

echo ">>> Docker installed successfully."
docker --version


# ─────────────────────────────────────────────
# SECTION 4: INSTALL JAVA
# Jenkins is built with Java, so Java must be
# installed before Jenkins can run
# ─────────────────────────────────────────────
echo ""
echo ">>> [4/7] Installing Java 17 (required by Jenkins)..."

# openjdk-17-jdk = Open source Java Development Kit, version 17
# Jenkins officially supports Java 17 (LTS version)
sudo apt-get install -y openjdk-17-jdk

echo ">>> Java installed."
java -version


# ─────────────────────────────────────────────
# SECTION 5: INSTALL JENKINS
# Like Docker, we install Jenkins from its own
# official repository to get the latest version
# ─────────────────────────────────────────────
echo ""
echo ">>> [5/7] Installing Jenkins..."

# Step 5a: Add Jenkins' official GPG signing key
# This proves Jenkins packages are genuine
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

# Step 5b: Add Jenkins' official package repository to Ubuntu
# "signed-by" points to the GPG key we just downloaded
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/" | \
  sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null

# Step 5c: Refresh package list now that Jenkins' repo is added
sudo apt-get update -y

# Step 5d: Install Jenkins
sudo apt-get install -y jenkins

# Step 5e: Start Jenkins now and enable it on reboot
sudo systemctl start jenkins
sudo systemctl enable jenkins

echo ">>> Jenkins installed successfully."
jenkins --version


# ─────────────────────────────────────────────
# SECTION 6: ALLOW JENKINS TO USE DOCKER
# Jenkins runs as its own system user called
# "jenkins". By default that user cannot run
# Docker commands. We add it to the docker group
# so the Jenkins pipeline can build images.
# ─────────────────────────────────────────────
echo ""
echo ">>> [6/7] Giving Jenkins permission to use Docker..."

# Add the "jenkins" system user to the "docker" group
# This lets Jenkins run: docker build, docker run, docker stop, etc.
# WITHOUT needing sudo — which is essential inside a Jenkins pipeline
sudo usermod -aG docker jenkins

# Restart Jenkins so it picks up the new group membership
sudo systemctl restart jenkins

echo ">>> Jenkins now has Docker access."


# ─────────────────────────────────────────────
# SECTION 7: OPEN FIREWALL PORTS (UFW)
# UFW = Uncomplicated Firewall (Ubuntu's built-in firewall)
# We need to open:
#   Port 22   = SSH (to connect to your server)
#   Port 80   = HTTP (to serve your website)
#   Port 8080 = Jenkins web UI (where you manage pipelines)
# ─────────────────────────────────────────────
echo ""
echo ">>> [7/7] Configuring firewall (UFW)..."

# Allow SSH — VERY IMPORTANT: do this first or you'll lock yourself out!
sudo ufw allow 22/tcp

# Allow HTTP traffic to your website
sudo ufw allow 80/tcp

# Allow Jenkins web UI
sudo ufw allow 8080/tcp

# Enable the firewall (--force skips the "are you sure?" prompt)
sudo ufw --force enable

# Show current firewall rules
sudo ufw status

echo ">>> Firewall configured."


# ─────────────────────────────────────────────
# FINAL: PRINT SUMMARY
# ─────────────────────────────────────────────
echo ""
echo "============================================="
echo "  INSTALLATION COMPLETE!"
echo "============================================="
echo ""
echo "  Docker  version: $(docker --version)"
echo "  Java    version: $(java -version 2>&1 | head -1)"
echo "  Jenkins status : $(sudo systemctl is-active jenkins)"
echo ""
echo "  Your EC2 Public IP: $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo ""
echo "  ACCESS YOUR SERVICES:"
echo "  Website  --> http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
echo "  Jenkins  --> http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo ""
echo "  NEXT STEP — Get Jenkins unlock password:"
echo "  sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
echo ""
echo "  NOTE: Log out and back in for docker group to apply:"
echo "  exit   (then SSH back in)"
echo "============================================="
