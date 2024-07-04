import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

// Placeholder arrays to be replaced dynamically
const endpointsList = __ENDPOINTS__;
const vus = __VUS__;

export const options = {
  scenarios: {},
};

// Define individual scenario functions dynamically
endpointsList.forEach((endpoint, index) => {
  options.scenarios[`scenario_${index + 1}`] = {
    executor: 'per-vu-iterations',
    maxDuration: '5m',
    vus: vus,
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

  // Fire the additional request to api.antrein.com
  const queueResponse = http.get(`https://api.antrein.com/bc/queue/register?project_id=${project_id}`, params);
  recordDuration(queueResponse, `https://api.antrein.com/bc/queue/register?project_id=${project_id}`);

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
