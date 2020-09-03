build:
	docker pull jenkins/jenkins
	docker volume create jenkins-data
run:
	docker run -p 8080:8080 --name=jenkins-master -d --env JAVA_OPTS="-Xmx8192m" -v jenkins-data:/var/lib/jenkins --env JENKINS_OPTS="--handlerCountMax=300" jenkins/jenkins

getpw:
	docker exec jenkins-master cat /var/jenkins_home/secrets/initialAdminPassword
	
start:
	docker start jenkins-master
stop:
	docker stop jenkins-master
clean:	stop
	docker rm -v jenkins-master
