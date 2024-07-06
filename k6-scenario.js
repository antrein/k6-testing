import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

// Placeholder arrays to be replaced dynamically
const endpointsList = new SharedArray('endpoints', () => __ENDPOINTS__);
const vus = __VUS__;

// Function to fetch infra_mode and be_mode with retry logic
function fetchInfraAndBeMode() {
  const maxRetries = 30;
  let retryCount = 0;
  let success = false;
  let infra_mode, be_mode;

  while (retryCount < maxRetries && !success) {
    let response = http.get('https://infra.antrein7.cloud');
    if (response.status === 200) {
      try {
        infra_mode = JSON.parse(response.body).infra_mode;
        be_mode = JSON.parse(response.body).be_mode;
        success = true;
      } catch (e) {
        console.error(`Error parsing response body: ${e}`);
      }
    }

    if (!success) {
      retryCount++;
      console.log(`Retry ${retryCount}/${maxRetries}: Failed to fetch infra_mode and be_mode. Retrying in 5 seconds...`);
      sleep(5);
    }
  }

  if (!success) {
    console.error("Failed to fetch infra_mode and be_mode after maximum retries. Exiting.");
    throw new Error("Failed to fetch infra_mode and be_mode after maximum retries.");
  }

  return { infra_mode, be_mode };
}

export function setup() {
  return fetchInfraAndBeMode();
}


// Define individual scenario functions dynamically
endpointsList.forEach((endpoint, index) => {
  options.scenarios[`scenario_${index + 1}`] = {
    executor: 'per-vu-iterations',
    maxDuration: '5m',
    vus: vus,
    exec: `scenario_${index + 1}`,
  };

  // Dynamically create the function
  exports[`scenario_${index + 1}`] = function (data) {
    runBatchRequests(endpoint, data.be_mode);
  };
});

function runBatchRequests(endpoint, be_mode) {
  let params = {
    timeout: '3000s',
  };

  // Extract project_id from endpoint
  const project_id = endpoint.match(/https:\/\/(?:.*\.)?(.+)\.antrein7.cloud/)[1];

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