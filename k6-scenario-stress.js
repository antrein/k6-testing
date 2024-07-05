import http from 'k6/http';
import { check, group, sleep } from 'k6';
import { Trend } from 'k6/metrics';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

// Placeholder arrays to be replaced dynamically
const endpointsList = __ENDPOINTS__;

export const options = {
  scenarios: {},
  thresholds: {
    'http_req_duration_success': ['p(95)<2000'], // 95% of successful requests should be under 2000ms
    'http_req_duration_fail': ['p(95)<2000'], // 95% of failed requests should be under 2000ms
    'http_req_failed': ['value<0.05'], // HTTP request failure rate should be less than 5%
  },
};

// Fetch infra_mode and be_mode from the endpoint
let response = http.get('https://infra.antrein5.cloud');
let infra_mode = JSON.parse(response.body).infra_mode;
let be_mode = JSON.parse(response.body).be_mode;

// Define individual scenario functions dynamically
endpointsList.forEach((endpoint, index) => {
  options.scenarios[`scenario_${index + 1}`] = {
    executor: 'per-vu-iterations',
    vus: 1, // Start with 1 VU
    iterations: 1000000, // Large number to keep the VU running
    maxDuration: '30m', // Maximum duration for each scenario
    exec: `scenario_${index + 1}`,
  };

  // Dynamically create the function
  exports[`scenario_${index + 1}`] = function () {
    runBatchRequests(endpoint);
  };
});

function runBatchRequests(endpoint) {
  let params = {
    timeout: '3000s',
  };

  // Extract project_id from endpoint
  const project_id = endpoint.match(/https:\/\/(.+)\.antrein\.cloud/)[1];

  // Fire the additional request to api.antrein5.cloud
  const queueResponse = http.get(`https://api.antrein5.cloud/${be_mode}/queue/register?project_id=${project_id}`, params);
  recordDuration(queueResponse, `https://api.antrein5.cloud/${be_mode}/queue/register?project_id=${project_id}`);

  // Fire the main request to the project endpoint
  const response = http.get(endpoint, params);
  recordDuration(response, endpoint);
}

function recordDuration(response, endpoint) {
  const isSuccess = check(response, {
    'status was 200': (r) => r.status === 200,
  });

  // Record metrics for successful and failed requests separately
  if (response.status === 200) {
    httpReqDurationSuccess.add(response.timings.duration);
  } else {
    httpReqDurationFail.add(response.timings.duration);
    logError(response, endpoint);
  }
}

function logError(response, endpoint) {
  const datetime = new Date().toISOString();
  const errorMessage = `Error: ${response.status} ${response.statusText}`;
  console.error(`${datetime}, ${endpoint}, ${errorMessage}`);
}

// Function to increase VUs gradually
export function handleSummary(data) {
  const currentVUs = options.scenarios[`scenario_1`].vus;
  if (data.metrics.http_req_failed.value > 0.9) {
    console.log(`System failed at ${currentVUs} VUs`);
    return {};
  } else {
    options.scenarios[`scenario_1`].vus = currentVUs + 1;
    console.log(`Increasing VUs to ${currentVUs + 1}`);
  }
}
