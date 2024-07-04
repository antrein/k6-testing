run:
	node run.js

krun:
	k6 run index.js

run-poc:
	k6 run poc.js

run-scenario:
	node test-scenario.js &
	sh run-scenario.sh