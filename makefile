IMAGE_NAME = reyshazni/antrein-testing-v5
TAG = latest

start:
	rm -f k6-error-logs.txt
	pm2 start test-scenario.js
	nohup ./run-scenario.sh &

stop:
	pm2 stop test-scenario.js

check:
	cat nohup.out

krun:
	k6 run index.js

run-poc:
	k6 run poc.js

run-scenario:
	node test-scenario.js &
	sudo ./run-scenario.sh

dbuild:
	docker build --platform=linux/amd64 -t $(IMAGE_NAME) .

drun:
	docker run --platform=linux/amd64 --rm -it -p 3001:3001 $(IMAGE_NAME) sh run-scenario.sh

dpush:
	docker push $(IMAGE_NAME)

connect:
	gcloud compute ssh sentry-test --project=pharindo-sandbox --zone=asia-southeast1-c -- -o ServerAliveInterval=3600
