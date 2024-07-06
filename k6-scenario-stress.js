import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

// Placeholder arrays to be replaced dynamically
const endpointsList = new SharedArray('endpoints', () => __ENDPOINTS__);
const initialVUs = 10; // Starting point
const maxVUs = 1500; // Example max value, can be adjusted

export const options = {
  scenarios: {
    stress_test: {
      executor: 'ramping-vus',
      startVUs: initialVUs,
      stages: [
        { duration: '2m', target: Math.floor(maxVUs * 0.01) },  // Ramp up to 1% of max VUs
        { duration: '2m', target: Math.floor(maxVUs * 0.1) },   // Ramp up to 10% of max VUs
        { duration: '2m', target: Math.floor(maxVUs * 0.25) },  // Ramp up to 25% of max VUs
        { duration: '2m', target: Math.floor(maxVUs * 0.5) },   // Ramp up to 50% of max VUs
        { duration: '2m', target: Math.floor(maxVUs * 0.75) },  // Ramp up to 75% of max VUs
        { duration: '2m', target: maxVUs },                    // Ramp up to max VUs
      ],
    },
  },
  thresholds: {
    'http_req_duration_success{status:200}': ['avg<1000'],
    'http_req_duration_fail{status:200}': ['avg<1000'],
  },
};

export function setup() {
  let response = http.get('https://infra.antrein7.cloud');
  let infra_mode = JSON.parse(response.body).infra_mode;
  let be_mode = JSON.parse(response.body).be_mode;

  return { infra_mode, be_mode };
}

export default function (data) {
  const endpoint = __ENDPOINT__; // Placeholder for a single endpoint
  
  runBatchRequests(endpoint, data.be_mode);

  sleep(1); // Pause between iterations
}

function runBatchRequests(endpoint, be_mode) {
  let params = {
    timeout: '3000s',
  };

  // Extract project_id from endpoint
  const project_id = endpoint.match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1];

  // Fire the additional request to api.antrein7.cloud
  const queueResponse = http.get(`https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, params);
  recordDuration(queueResponse, `https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, project_id);

  // Fire the main request to the project endpoint
  const response = http.get(endpoint, params);
  recordDuration(response, endpoint, project_id);
}

function recordDuration(response, endpoint, project_id) {
  const isSuccess = check(response, {
    'status was 200': (r) => r.status === 200,
  });

  // Record metrics for successful and failed requests separately
  if (response.status === 200) {
    httpReqDurationSuccess.add(response.timings.duration);
  } else {
    httpReqDurationFail.add(response.timings.duration);
    logStatus(endpoint, 'fail', response.status, project_id);
  }
}

function logStatus(endpoint, status, httpStatus, project_id) {
  const datetime = new Date().toISOString();
  const message = `Project ID: ${project_id}, Endpoint: ${endpoint}, Status: ${status}, HTTP Status: ${httpStatus}`;
  console.log(`${datetime} - ${message}`);
}

function monitorSuccessRate() {
  let successRequests = __ITER - httpReqDurationFail.count;
  let successRate = (successRequests / __ITER) * 100;

  if (successRate < 20) {
    console.error(`Success rate fell below 20%: ${successRate}%`);
    // Implement logic to stop the test, such as calling a function or API to halt execution.
    // k6 currently doesn't support dynamic test stopping within the test script.
  }
}

setInterval(monitorSuccessRate, 60000); // Check success rate every minute
