import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { sleep } from 'k6';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

// Placeholder array to be replaced dynamically
const endpoint = __ENDPOINT__;
const vus = 1;
const token = "__TOKEN__";

export const options = {
  scenarios: {
    my_scenario: {
      executor: 'constant-vus',
      vus: vus,
      duration: '1m',
    },
  },
};

function fetchInfraAndBeMode() {
  const maxRetries = 30;
  let retryCount = 0;
  let success = false;
  let infra_mode, be_mode;

  while (retryCount < maxRetries && !success) {
    let response = http.get('https://infra.antrein14.cloud');
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

export default function (data) {
  const project_id = 'your_project_id'; // This will be dynamically replaced
  const finalEndpoint = endpoint.replace('__BE_MODE__', data.be_mode).replace('__PROJECT_ID__', project_id);
  runRequest(finalEndpoint, data.be_mode);
}

function runRequest(endpoint, be_mode) {
  let params = {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
    timeout: '3000s',
  };

  const response = http.get(endpoint, params);
  recordDuration(response, endpoint);
}

function recordDuration(response, endpoint) {
  const isSuccess = check(response, {
    'status was 200': (r) => r.status === 200,
  });

  if (response.status === 200) {
    httpReqDurationSuccess.add(response.timings.duration);
  } else {
    httpReqDurationFail.add(response.timings.duration);
    logStatus(endpoint, 'fail', response.status);
  }
}

function logStatus(endpoint, status, httpStatus) {
  const datetime = new Date().toISOString();
  const message = `Endpoint: ${endpoint}, Status: ${status}, HTTP Status: ${httpStatus}`;
  console.log(`${datetime} - ${message}`);
}
