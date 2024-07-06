import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

const endpointsList = new SharedArray('endpoints', () => [
  "https://demo1.antrein7.cloud"
]);
const minVUs = 100;
const maxVUs = 20000;

export const options = {
  scenarios: {
    stress_test: {
      executor: 'ramping-vus',
      startVUs: minVUs,
      stages: [
        { duration: '10s', target: Math.floor(maxVUs * 0.1) },
        { duration: '10s', target: Math.floor(maxVUs * 0.25) },
        { duration: '10s', target: Math.floor(maxVUs * 0.5) },
        { duration: '10s', target: Math.floor(maxVUs * 0.75) },
        { duration: '10s', target: maxVUs },
        { duration: '10s', target: maxVUs },
      ],
      gracefulStop: '30s',
    },
  },
  thresholds: {
    'http_req_duration_success{status:200}': ['avg<1000'],
    'http_req_duration_fail{status:200}': ['avg<1000'],
  },
};

let totalRequests = 0;
let successRequests = 0;
let failedRequests = 0;

export function setup() {
  let response = http.get('https://infra.antrein7.cloud');
  let infra_mode = JSON.parse(response.body).infra_mode;
  let be_mode = JSON.parse(response.body).be_mode;
  return { infra_mode, be_mode };
}

export default function (data) {
  endpointsList.forEach((endpoint) => {
    runBatchRequests(endpoint, data.be_mode);
  });

  checkSuccessRate();
  sleep(1);
}

function runBatchRequests(endpoint, be_mode) {
  let params = { timeout: '60s' }; // Increase timeout to 60 seconds
  const project_id = endpoint.match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1];

  const queueResponse = http.get(`https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, params);
  recordDuration(queueResponse, `https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, project_id);

  const response = http.get(endpoint, params);
  recordDuration(response, endpoint, project_id);
}

function recordDuration(response, endpoint, project_id) {
  totalRequests++;
  const isSuccess = check(response, { 'status was 200': (r) => r.status === 200 });

  if (isSuccess) {
    successRequests++;
    httpReqDurationSuccess.add(response.timings.duration);
  } else {
    failedRequests++;
    httpReqDurationFail.add(response.timings.duration);
    logStatus(endpoint, 'fail', response.status, project_id);
  }
}

function logStatus(endpoint, status, httpStatus, project_id) {
  const datetime = new Date().toISOString();
  const message = `Project ID: ${project_id}, Endpoint: ${endpoint}, Status: ${status}, HTTP Status: ${httpStatus}`;
  console.log(`${datetime} - ${message}`);
}

function checkSuccessRate() {
  const totalRequests = httpReqDurationSuccess.count + httpReqDurationFail.count;
  const successRequests = httpReqDurationSuccess.count;
  const successRate = (successRequests / totalRequests) * 100;

  if (successRate < 20) {
    console.error(`Success rate fell below 20%: ${successRate}%`);
    throw new Error('Success rate fell below 20%, stopping test.');
  }
}

export function handleSummary(data) {
  const successRate = (successRequests / totalRequests) * 100;

  return {
    stdout: `Test summary:
    Total Requests: ${totalRequests}
    Successful Requests: ${successRequests}
    Failed Requests: ${failedRequests}
    Success Rate: ${successRate.toFixed(2)}%
    Avg Duration Success: ${httpReqDurationSuccess.avg}
    Avg Duration Fail: ${httpReqDurationFail.avg}\n`,
  };
}
