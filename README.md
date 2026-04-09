# CloudOps — Static Website on AWS EC2 with CI/CD

A production-grade DevOps project that deploys a static website to AWS EC2 using Docker containers and a Jenkins CI/CD pipeline. Every `git push` to GitHub automatically builds and deploys the latest version — zero manual steps.

---

## What This Project Does

```
You push code to GitHub
        ↓
GitHub sends a webhook to Jenkins on EC2
        ↓
Jenkins builds a Docker image from your Dockerfile
        ↓
Jenkins stops the old container, starts the new one
        ↓
Your updated website is live on port 80 — in under 3 minutes
```

---

## Tech Stack

| Tool | Purpose |
|------|---------|
| HTML / CSS / JS | The static website frontend |
| Docker + nginx | Containerizes the site — runs the same everywhere |
| Jenkins | CI/CD server — automates build and deploy on every push |
| AWS EC2 (Ubuntu 22.04) | Cloud server hosting Jenkins and the live website |
| Git + GitHub | Source control + webhook trigger for the pipeline |

---

## Project Structure

```
my-website/
├── index.html          # Website homepage
├── style.css           # Styles (dark tech theme, responsive)
├── script.js           # Animations, terminal effect, scroll interactions
├── Dockerfile          # Builds nginx container with your website files
├── .dockerignore       # Files to exclude from Docker build
├── Jenkinsfile         # CI/CD pipeline definition (6 stages)
├── setup-ec2.sh        # One-time script to install Docker + Jenkins on EC2
└── README.md           # This file
```

---

## Prerequisites

Before you start, make sure you have:

- An **AWS account** (free tier works fine)
- **Git** installed on your computer
- **Docker Desktop** installed locally (for testing)
- A **GitHub account** with a new empty repository created
- Your AWS EC2 **key pair** `.pem` file downloaded

---

## Setup Guide

### Step 1 — Clone or download this project

```bash
git clone https://github.com/YOUR_USERNAME/static-website-aws.git
cd static-website-aws
```

Or create the folder manually and copy all the project files into it.

---

### Step 2 — Test the website locally with Docker

Before touching AWS, confirm everything works on your own machine:

```bash
# Build the Docker image
docker build -t my-website .

# Run the container on port 80
docker run -d -p 80:80 --name cloudops-test my-website

# Open http://localhost in your browser — site should be live

# Stop and clean up when done
docker stop cloudops-test
docker rm cloudops-test
```

---

### Step 3 — Launch an EC2 instance on AWS

1. Go to **AWS Console → EC2 → Launch Instance**
2. Use these settings:

| Setting | Value |
|---------|-------|
| Name | `cloudops-server` |
| AMI | Ubuntu Server 22.04 LTS |
| Instance type | `t2.micro` (free tier) |
| Key pair | Create new → download `.pem` file |

3. In **Security Group**, add these inbound rules:

| Type | Port | Source |
|------|------|--------|
| SSH | 22 | My IP |
| HTTP | 80 | Anywhere (0.0.0.0/0) |
| Custom TCP | 8080 | Anywhere (0.0.0.0/0) |

4. Click **Launch Instance** and wait ~1 minute for it to start

---

### Step 4 — Install Docker and Jenkins on EC2

SSH into your new server and run the setup script:

```bash
# SSH into EC2 (replace with your key file and EC2 public IP)
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP

# Upload the setup script from your local machine
# (run this on your LOCAL machine, not on EC2)
scp -i your-key.pem setup-ec2.sh ubuntu@YOUR_EC2_PUBLIC_IP:~/

# Back on EC2 — make it executable and run it
chmod +x setup-ec2.sh
sudo ./setup-ec2.sh
```

The script installs (in order):
1. System updates
2. Required tools (curl, wget, gnupg)
3. Docker CE + CLI + containerd
4. Java 17 (Jenkins requires Java)
5. Jenkins
6. Adds `jenkins` and `ubuntu` users to the docker group
7. Configures UFW firewall (ports 22, 80, 8080)

**After the script finishes — log out and back in:**

```bash
exit
ssh -i your-key.pem ubuntu@YOUR_EC2_PUBLIC_IP
```

This is required for the docker group permissions to take effect.

---

### Step 5 — Set up Jenkins

**Open Jenkins in your browser:**

```
http://YOUR_EC2_PUBLIC_IP:8080
```

**Get the unlock password:**

```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

Paste the password into Jenkins, then:

1. Click **Install suggested plugins** — wait for it to finish (~3 minutes)
2. Create your admin user
3. Click **Save and Finish**

---

### Step 6 — Create a Jenkins pipeline job

1. **Dashboard → New Item**
2. Name it `static-website-aws`
3. Select **Pipeline** → click **OK**
4. Scroll to the **Pipeline** section:
   - Definition: `Pipeline script from SCM`
   - SCM: `Git`
   - Repository URL: your GitHub repo URL (e.g. `https://github.com/username/static-website-aws.git`)
   - Branch: `*/main`
   - Script Path: `Jenkinsfile`
5. Click **Save**

---

### Step 7 — Connect GitHub to Jenkins via Webhook

This makes Jenkins automatically run whenever you push to GitHub.

**In your GitHub repository:**

1. Go to **Settings → Webhooks → Add webhook**
2. Set these values:

| Field | Value |
|-------|-------|
| Payload URL | `http://YOUR_EC2_PUBLIC_IP:8080/github-webhook/` |
| Content type | `application/json` |
| Which events | Just the push event |

3. Click **Add webhook** — GitHub will send a test ping

**In Jenkins job settings:**

1. Open your pipeline job → **Configure**
2. Under **Build Triggers**, tick `GitHub hook trigger for GITScm polling`
3. Click **Save**

---

### Step 8 — Push your code and watch it deploy

```bash
# On your local machine, inside the project folder
git add .
git commit -m "Initial deployment"
git push origin main
```

Then go to Jenkins at `http://YOUR_EC2_PUBLIC_IP:8080` and watch the pipeline run through all 6 stages. When it turns green, open:

```
http://YOUR_EC2_PUBLIC_IP
```

Your website is live! 🎉

---

## Pipeline Stages

The `Jenkinsfile` defines 6 stages that run on every push:

| Stage | What it does |
|-------|-------------|
| **Checkout** | Clones the latest code from GitHub onto EC2 |
| **Build Docker Image** | Runs `docker build` — tags image with build number |
| **Stop Old Container** | Stops and removes the previously running container |
| **Run New Container** | Starts fresh container on port 80 with auto-restart |
| **Health Check** | Curls `localhost` to confirm the site is responding |
| **Clean Up Old Images** | Removes unused Docker images to save disk space |

---

## Useful Commands

**Check running containers on EC2:**
```bash
docker ps
```

**View Jenkins pipeline logs:**
```bash
# Jenkins web UI → your job → build number → Console Output
```

**Manually restart the website container:**
```bash
docker restart cloudops-live
```

**Check Jenkins service status:**
```bash
sudo systemctl status jenkins
```

**View container logs (nginx access logs):**
```bash
docker logs cloudops-live
```

**SSH into the running container:**
```bash
docker exec -it cloudops-live sh
```

**Stop and remove everything (full reset):**
```bash
docker stop cloudops-live
docker rm cloudops-live
docker rmi cloudops-website:latest
```

---

## How the Dockerfile Works

```dockerfile
FROM nginx:alpine       # Tiny Linux + nginx web server (~23MB total)
WORKDIR /usr/share/nginx/html  # nginx serves files from this folder
RUN rm -rf ./*          # Remove default nginx welcome page
COPY . .                # Copy your website files in
EXPOSE 80               # Document that port 80 is used
CMD ["nginx", "-g", "daemon off;"]  # Start nginx in foreground
```

---

## Troubleshooting

**Website not loading on port 80:**
```bash
# Check if container is running
docker ps

# Check if port 80 is being used
sudo lsof -i :80

# Check container logs for errors
docker logs cloudops-live
```

**Jenkins not loading on port 8080:**
```bash
# Check Jenkins is running
sudo systemctl status jenkins

# Restart Jenkins
sudo systemctl restart jenkins

# Check Jenkins logs
sudo journalctl -u jenkins -n 50
```

**Pipeline fails at "Build Docker Image":**
```bash
# Make sure Jenkins user can use Docker
sudo -u jenkins docker ps

# If permission denied, re-add jenkins to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

**GitHub webhook not triggering Jenkins:**
- Confirm EC2 Security Group has port 8080 open to `0.0.0.0/0`
- Check webhook delivery in GitHub → Settings → Webhooks → Recent Deliveries
- Make sure `GitHub hook trigger for GITScm polling` is ticked in Jenkins job

---

## What You Learned

By completing this project you have hands-on experience with:

- Writing a `Dockerfile` and building Docker images
- Running and managing Docker containers
- Setting up a Jenkins CI/CD server on a cloud VM
- Writing a `Jenkinsfile` pipeline with multiple stages
- Connecting GitHub to Jenkins using webhooks
- Deploying to AWS EC2 and managing server infrastructure
- Linux server administration (UFW firewall, systemctl, user groups)

---

## Author

Built as a DevOps learning project — deployed on AWS EC2 using Docker and Jenkins.
