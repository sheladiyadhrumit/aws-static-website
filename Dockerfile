# =============================================
#  CloudOps — Static Website Dockerfile
#  Project: static-website-aws
# =============================================

# STEP 1: Choose the base image
# nginx:alpine = nginx web server built on Alpine Linux (tiny OS, only ~5MB)
# This is the official, trusted image from Docker Hub
# "alpine" version is much smaller than plain "nginx" (~23MB vs ~140MB)
FROM nginx:alpine

# STEP 2: Set the working directory inside the container
# All file operations after this line happen inside /usr/share/nginx/html
# This is the folder nginx uses to serve website files — its "public" folder
WORKDIR /usr/share/nginx/html

# STEP 3: Remove the default nginx welcome page
# nginx:alpine comes with a default "Welcome to nginx!" page
# We delete it so our own files are the only thing served
RUN rm -rf ./*

# STEP 4: Copy our website files into the container
# COPY <source on your computer>  <destination inside container>
# The dot (.) means "copy everything from the current folder"
# into /usr/share/nginx/html (the WORKDIR we set above)
# .dockerignore controls what gets skipped (see .dockerignore file)
COPY . .

# STEP 5: Tell Docker that this container listens on port 80
# Port 80 is the standard HTTP port — the same port browsers use by default
# This is just documentation; the actual port mapping happens when you run the container
EXPOSE 80

# STEP 6: The command to run when the container starts
# "nginx" = start the nginx web server
# "-g" = pass a global config directive
# "daemon off" = run nginx in the foreground (not as a background service)
# Docker requires the main process to stay in the foreground — if it exits, the container stops
CMD ["nginx", "-g", "daemon off;"]
