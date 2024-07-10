IMAGE_NAME = reyshazni/antrein-testing-v5
TAG = latest

start:
	pm2 stop test-scenario.js
	rm -f k6-error-logs.txt
	rm nohup.out
	pm2 start test-scenario.js
	nohup ./run-scenario.sh &

start-be:
	@pm2 stop be-run.js || echo "be-run.js not running, skipping stop."
	@pm2 stop be-test.js || echo "be-test.js not running, skipping stop."
	@[ -f k6-error-logs-be.txt ] && rm -f k6-error-logs-be.txt || echo "k6-error-logs-be.txt not found, skipping removal."
	@[ -f nohup.out ] && rm nohup.out || echo "nohup.out not found, skipping removal."
	@pm2 start be-run.js
	@pm2 start be-test.js
	@nohup ./be-run.sh &

stop-be:
	@pkill -f be-run.sh || echo "be-run.sh not running, skipping stop."


check:
	cat nohup.out

stop:
	pkill -f run-scenario.sh

connect:
	gcloud compute ssh sentry-test --project=pharindo-sandbox --zone=asia-southeast1-c -- -o ServerAliveInterval=3600
