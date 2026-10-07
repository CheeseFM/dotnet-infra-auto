node {
    stage('Preparation') {
        catchError(buildResult: 'SUCCESS') {
            sh 'docker stop todorunning todoappdb todotestdb'
            sh 'docker rm todorunning todoappdb todotestdb'
            sh 'docker network rm todonet'
        }
    }
    stage('Build') {
        build 'DotnetVoorbeeldApp'
    }
    stage('Results') {
        build 'DotnetVoorbeeldAppTest'
    }
}
