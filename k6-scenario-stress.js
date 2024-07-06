import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

const endpointsList = new SharedArray('endpoints', () => __ENDPOINTS__);
const vus = __VUS__;
const be_mode = "bc"

export const options = {
  scenarios: {},
};

endpointsList.forEach((endpoint, index) => {
  options.scenarios[`scenario_${index + 1}`] = {
    executor: 'per-vu-iterations',
    maxDuration: '5m',
    vus: vus,
    exec: `scenario_${index + 1}`,
  };

  exports[`scenario_${index + 1}`] = function (data) {
    runBatchRequests(endpoint, be_mode);
  };
});

function runBatchRequests(endpoint, be_mode) {
  let params = {
    timeout: '3000s',
  };

  const project_id = endpoint.match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1];

  const queueResponse = http.get(`https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, params);
  recordDuration(queueResponse, `https://${project_id}.api.antrein7.cloud/${be_mode}/queue/register?project_id=${project_id}`, project_id);

  const response = http.get(endpoint, params);
  recordDuration(response, endpoint, project_id);
}

function recordDuration(response, endpoint, project_id) {
  const isSuccess = check(response, {
    'status was 200': (r) => r.status === 200,
  });

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
