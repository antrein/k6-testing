IMAGE_NAME = reyshazni/antrein-testing-v5
TAG = latest

start:
	pm2 stop test-scenario.js
	rm -f k6-error-logs.txt
	rm nohup.out
	pm2 start test-scenario.js
	nohup ./run-scenario.sh &

check:
	cat nohup.out

stop:
	pkill -f run-scenario.sh

connect:
	gcloud compute ssh sentry-test --project=pharindo-sandbox --zone=asia-southeast1-c -- -o ServerAliveInterval=3600
