import http from 'k6/http';
import { check } from 'k6';
import { Trend } from 'k6/metrics';

// Define custom trends for success and failure durations
const httpReqDurationSuccess = new Trend('http_req_duration_success');
const httpReqDurationFail = new Trend('http_req_duration_fail');

export const options = {
  scenarios: {
    constant_load: {
      executor: 'per-vu-iterations',
      vus: __VUS__,
      iterations: 1,
      maxDuration: '1m',
    },
  },
};

export default function () {
  let params = {
    timeout: '120s',
  };

  let res = http.get('__ENDPOINT__', params);

  const isSuccess = check(res, {
    'status was 200': (r) => r.status === 200,
  });

  // Record metrics for successful and failed requests separately
  if (res.status === 200) {
    httpReqDurationSuccess.add(res.timings.duration);
  } else {
    httpReqDurationFail.add(res.timings.duration);
  }
}
