// =============================================
//  CloudOps — Jenkinsfile
//  CI/CD Pipeline for Static Website on AWS EC2
//  Project: static-website-aws
//
//  HOW THIS WORKS:
//  1. You push code to GitHub
//  2. GitHub sends a webhook signal to Jenkins
//  3. Jenkins runs this file top to bottom
//  4. Your updated website is live in ~2 minutes
// =============================================

pipeline {

    // "agent any" means: run this pipeline on any
    // available Jenkins worker (in our case, the EC2
    // server itself is the only worker, so it runs there)
    agent any

    // ── ENVIRONMENT VARIABLES ──────────────────
    // Define values here once, reuse them everywhere.
    // Change IMAGE_NAME or CONTAINER_NAME here and
    // it updates across the entire pipeline automatically.
    environment {
        IMAGE_NAME     = "cloudops-website"   // Name for the Docker image we build
        CONTAINER_NAME = "cloudops-live"      // Name for the running Docker container
        PORT           = "80"                 // Port the website is served on
    }

    // ── OPTIONS ───────────────────────────────
    // Global settings that apply to the whole pipeline
    options {
        // If the pipeline is still running after 10 minutes,
        // something went wrong — kill it automatically
        timeout(time: 10, unit: 'MINUTES')

        // Keep logs from the last 5 builds only (saves disk space on EC2)
        buildDiscarder(logRotator(numToKeepStr: '5'))

        // Show timestamps next to every log line — great for debugging
        timestamps()
    }

    // ══════════════════════════════════════════
    // STAGES — the actual steps of the pipeline
    // Each stage shows up as a separate block in
    // the Jenkins UI so you can see exactly where
    // a failure happened
    // ══════════════════════════════════════════
    stages {

        // ── STAGE 1: CHECKOUT ─────────────────
        // Jenkins clones your GitHub repository
        // onto the EC2 server so it has the latest
        // code files to work with
        stage('Checkout') {
            steps {
                echo '>>> Checking out latest code from GitHub...'

                // "checkout scm" is a Jenkins built-in command.
                // "scm" = Source Control Management.
                // It uses the GitHub URL you configured in the
                // Jenkins job settings — no need to hardcode it here.
                checkout scm

                echo '>>> Checkout complete.'

                // Print the latest git commit hash and message
                // so you can see exactly which code was deployed
                sh 'git log -1 --pretty=format:"Deploying commit: %h — %s by %an"'
            }
        }

        // ── STAGE 2: BUILD DOCKER IMAGE ───────
        // Jenkins runs "docker build" to create a
        // fresh Docker image from your Dockerfile.
        // The image contains nginx + your website files.
        stage('Build Docker Image') {
            steps {
                echo '>>> Building Docker image...'

                // docker build  = create a Docker image
                // -t            = tag (give it a name)
                // IMAGE_NAME    = "cloudops-website" (from environment above)
                // :${BUILD_NUMBER} = Jenkins auto-increments this number
                //                   each build: :1, :2, :3 ...
                //                   This lets you track exactly which
                //                   build is running in production
                // . (dot)       = use the Dockerfile in the current directory
                sh 'docker build -t ${IMAGE_NAME}:${BUILD_NUMBER} .'

                // Also tag this image as "latest" so it's easy to reference
                // "latest" always points to the most recent successful build
                sh 'docker tag ${IMAGE_NAME}:${BUILD_NUMBER} ${IMAGE_NAME}:latest'

                echo ">>> Image built: ${IMAGE_NAME}:${BUILD_NUMBER}"
            }
        }

        // ── STAGE 3: STOP OLD CONTAINER ───────
        // Before we start the new version, we need to
        // stop and remove the currently running container.
        //
        // WHY: Docker won't let two containers use
        // the same name or the same port at the same time.
        // We must remove the old one first.
        //
        // The "|| true" trick: if no container is running
        // (e.g. very first deployment), docker stop/rm
        // would fail and stop the pipeline. Adding "|| true"
        // means "if this command fails, that's OK, keep going."
        stage('Stop Old Container') {
            steps {
                echo '>>> Stopping old container (if running)...'

                // Stop the container gracefully (sends SIGTERM signal)
                // || true = don't fail if container doesn't exist
                sh 'docker stop ${CONTAINER_NAME} || true'

                // Remove the stopped container
                // A stopped container still exists on disk until removed
                // || true = don't fail if container doesn't exist
                sh 'docker rm ${CONTAINER_NAME} || true'

                echo '>>> Old container removed.'
            }
        }

        // ── STAGE 4: RUN NEW CONTAINER ────────
        // Start a fresh container from the image
        // we just built in Stage 2
        stage('Run New Container') {
            steps {
                echo '>>> Starting new container...'

                // docker run = create and start a container
                // -d         = detached mode (run in background)
                //              Without -d, Jenkins would wait forever
                //              for the container to stop before continuing
                // --name     = give the container our chosen name
                // -p 80:80   = port mapping: "host port : container port"
                //              Traffic arriving at EC2's port 80
                //              is forwarded to port 80 inside the container
                //              (nginx listens on port 80 inside the container)
                // --restart unless-stopped = if the container crashes,
                //              Docker will automatically restart it.
                //              It also starts automatically when EC2 reboots.
                //              "unless-stopped" means: restart always, EXCEPT
                //              if someone manually ran "docker stop"
                // IMAGE_NAME:latest = use the image we just tagged as latest
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p ${PORT}:80 \
                        --restart unless-stopped \
                        ${IMAGE_NAME}:latest
                '''

                echo '>>> New container started on port ${PORT}.'
            }
        }

        // ── STAGE 5: HEALTH CHECK ─────────────
        // After starting the container, wait a moment
        // and then verify the website is actually responding.
        // This catches cases where the container starts but
        // nginx crashes immediately due to a config error.
        stage('Health Check') {
            steps {
                echo '>>> Running health check...'

                // Wait 5 seconds to give nginx time to fully start up
                // before we try to reach it
                sh 'sleep 5'

                // curl = make an HTTP request to the website
                // --fail   = exit with error code if HTTP response is not 200 OK
                // --silent = don't show progress bar (cleaner logs)
                // --max-time 10 = give up after 10 seconds (don't hang forever)
                // localhost = the website running on this same EC2 server
                sh 'curl --fail --silent --max-time 10 http://localhost'

                echo '>>> Health check passed — website is live!'
            }
        }

        // ── STAGE 6: CLEAN UP OLD IMAGES ──────
        // Every build creates a new Docker image with
        // a build number tag (:1, :2, :3 ...).
        // Without cleanup, these pile up and fill your
        // EC2 disk over time.
        // This stage removes images that are no longer
        // being used by any container ("dangling" images).
        stage('Clean Up Old Images') {
            steps {
                echo '>>> Removing unused Docker images to save disk space...'

                // docker image prune = remove unused images
                // -f = force (don't ask "are you sure?")
                // This only removes "dangling" images — images not
                // tagged and not used by any container.
                // Your running container's image is safe.
                sh 'docker image prune -f'

                echo '>>> Cleanup complete.'
            }
        }
    }
    // ══════════════════════════════════════════
    // END OF STAGES
    // ══════════════════════════════════════════


    // ── POST ACTIONS ──────────────────────────
    // These run AFTER all stages finish,
    // regardless of whether they passed or failed.
    // Great for sending notifications or cleanup.
    post {

        // Runs only if ALL stages passed successfully
        success {
            echo """
            ╔══════════════════════════════════╗
            ║   DEPLOYMENT SUCCESSFUL          ║
            ║   Build #${BUILD_NUMBER}         ║
            ║   Image: ${IMAGE_NAME}:${BUILD_NUMBER} ║
            ║   Website is live on port ${PORT}  ║
            ╚══════════════════════════════════╝
            """
        }

        // Runs only if any stage FAILED
        failure {
            echo """
            ╔══════════════════════════════════╗
            ║   DEPLOYMENT FAILED              ║
            ║   Build #${BUILD_NUMBER}         ║
            ║   Check the logs above           ║
            ║   Old container still running    ║
            ╚══════════════════════════════════╝
            """

            // IMPORTANT: If the pipeline fails, the old container
            // may have been stopped (Stage 3) but the new one
            // failed to start (Stage 4). This restarts the last
            // known-good image so the website stays online.
            // "|| true" so this doesn't cause another failure
            // if the old container doesn't exist either.
            sh 'docker start ${CONTAINER_NAME} || true'
        }

        // Runs ALWAYS — whether success or failure
        always {
            echo '>>> Pipeline finished. Build: #${BUILD_NUMBER}'

            // Print the current running containers so you can
            // see the state of the server after every pipeline run
            sh 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
        }
    }
}
