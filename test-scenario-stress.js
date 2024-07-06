const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const minVUs = 1000;
const maxVUs = 20000;
const stepVUs = 1000;
const endpoint = "https://demo1.antrein7.cloud";

function runTest(vus) {
  const script = path.join(__dirname, 'k6-scenario-stress.js');
  const tempScript = path.join(__dirname, 'temp_k6_script_stress.js');

  let k6Script = fs.readFileSync(script, 'utf8');
  k6Script = k6Script.replace('__ENDPOINTS__', JSON.stringify([endpoint]));
  k6Script = k6Script.replace('__VUS__', vus);

  fs.writeFileSync(tempScript, k6Script);

  try {
    execSync(`k6 run ${tempScript} --summary-export output.json`);
  } catch (error) {
    console.error('Error running k6:', error);
  }

  fs.unlinkSync(tempScript);
}

function getSuccessRate() {
  const summary = JSON.parse(fs.readFileSync('output.json', 'utf8'));
  const totalRequests = summary.metrics.http_reqs.count;
  const failedRequests = summary.metrics.http_req_failed.passes;
  const successRate = ((totalRequests - failedRequests) / totalRequests) * 100;
  return successRate;
}

for (let vus = minVUs; vus <= maxVUs; vus += stepVUs) {
  console.log(`Running test with ${vus} VUs`);
  runTest(vus);
  const successRate = getSuccessRate();
  console.log(`Success rate: ${successRate}%`);
  if (successRate < 20) {
    console.log(`Success rate fell below 20% with ${vus} VUs, stopping test.`);
    break;
  }
}
