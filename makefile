IMAGE_NAME = reyshazni/antrein-testing-v5
TAG = latest

run:
	node run.js

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
	gcloud compute ssh sentry-test --zone asia-southeast1-c --project pharindo-sandbox
