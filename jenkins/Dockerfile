pipeline {
    agent any
    
    environment {
        // Application details
        APP_NAME = 'tic-tac-toe-game'
        APP_VERSION = '1.0.0'
        
        // Docker Hub credentials (configure in Jenkins credentials)
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKER_IMAGE = 'ashuz/nodejs-tictactoe'
        
        // Nexus configuration
        NEXUS_URL = 'http://nexus:8081'
        NEXUS_REPO = 'npm-releases'
        NEXUS_CREDENTIALS = credentials('nexus-credentials')
        
        // SonarQube configuration
        SONAR_HOST_URL = 'http://sonarqube:9000'
        SONAR_TOKEN = credentials('sonarqube-token')
        
        // Artifact details
        ARTIFACT_NAME = "${APP_NAME}-${APP_VERSION}.tar.gz"
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from Git...'
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                echo '📦 Installing Node.js dependencies...'
                sh '''
                    node --version
                    npm --version
                    npm install
                '''
            }
        }
        
        stage('Lint') {
            steps {
                echo '🔍 Running ESLint...'
                sh 'npm run lint || true'
            }
        }
        
        stage('Test') {
            steps {
                echo '🧪 Running tests with coverage...'
                sh 'npm test'
            }
            post {
                always {
                    // Publish test results if available
                    junit testResults: '**/junit.xml', allowEmptyResults: true
                    // Publish coverage report
                    publishHTML(target: [
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'coverage/lcov-report',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }
        
        stage('SonarQube Analysis') {
            steps {
                echo '📊 Running SonarQube code analysis...'
                script {
                    // Using SonarQube Scanner
                    def scannerHome = tool 'SonarQubeScanner'
                    withSonarQubeEnv('SonarQube') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                            -Dsonar.projectKey=tic-tac-toe-nodejs \
                            -Dsonar.sources=. \
                            -Dsonar.host.url=${SONAR_HOST_URL} \
                            -Dsonar.login=\${SONAR_TOKEN} \
                            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
                        """
                    }
                }
            }
        }
        
        stage('Quality Gate') {
            steps {
                echo '🚦 Waiting for SonarQube Quality Gate...'
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: false
                }
            }
        }
        
        stage('Build Artifact') {
            steps {
                echo '📦 Creating application artifact...'
                sh '''
                    # Create a clean build directory
                    rm -rf build
                    mkdir -p build
                    
                    # Copy necessary files for production
                    cp -r public build/
                    cp server.js build/
                    cp package*.json build/
                    
                    # Create tarball
                    tar -czf ${ARTIFACT_NAME} -C build .
                    
                    echo "Artifact created: ${ARTIFACT_NAME}"
                    ls -lh ${ARTIFACT_NAME}
                '''
            }
        }
        
        stage('Upload to Nexus') {
            steps {
                echo '⬆️  Uploading artifact to Nexus...'
                script {
                    sh """
                        curl -v -u ${NEXUS_CREDENTIALS_USR}:\${NEXUS_CREDENTIALS_PSW} \
                        --upload-file ${ARTIFACT_NAME} \
                        ${NEXUS_URL}/repository/${NEXUS_REPO}/${ARTIFACT_NAME}
                    """
                }
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo '🐳 Building Docker image...'
                script {
                    // Get the network that Jenkins container is using
                    def jenkinsNetwork = sh(
                        script: "docker inspect jenkins --format '{{range \$key, \$value := .NetworkSettings.Networks}}{{\$key}}{{end}}'",
                        returnStdout: true
                    ).trim()
                    
                    // Disable BuildKit to support custom networks
                    sh """
                        DOCKER_BUILDKIT=0 docker build \
                        --network ${jenkinsNetwork} \
                        --build-arg NEXUS_URL=${NEXUS_URL} \
                        --build-arg NEXUS_REPO=${NEXUS_REPO} \
                        --build-arg ARTIFACT_NAME=${APP_NAME} \
                        --build-arg ARTIFACT_VERSION=${APP_VERSION} \
                        --build-arg NEXUS_USER=${NEXUS_CREDENTIALS_USR} \
                        --build-arg NEXUS_PASS=\${NEXUS_CREDENTIALS_PSW} \
                        -t ${DOCKER_IMAGE}:${APP_VERSION} \
                        -t ${DOCKER_IMAGE}:latest \
                        .
                    """
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                echo '⬆️  Pushing Docker image to Docker Hub...'
                script {
                    sh """
                        echo \${DOCKERHUB_CREDENTIALS_PSW} | docker login -u ${DOCKERHUB_CREDENTIALS_USR} --password-stdin
                        docker push ${DOCKER_IMAGE}:${APP_VERSION}
                        docker push ${DOCKER_IMAGE}:latest
                        docker logout
                    """
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                echo '🧹 Cleaning up...'
                sh '''
                    # Remove local Docker images to save space
                    docker rmi ${DOCKER_IMAGE}:${APP_VERSION} || true
                    docker rmi ${DOCKER_IMAGE}:latest || true
                    
                    # Clean build artifacts
                    rm -rf build
                    rm -f ${ARTIFACT_NAME}
                '''
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully!'
            echo "Docker image available at: ${DOCKER_IMAGE}:${APP_VERSION}"
        }
        failure {
            echo '❌ Pipeline failed!'
        }
        always {
            echo '📊 Pipeline execution finished.'
            // Clean workspace if needed
            cleanWs()
        }
    }
}


