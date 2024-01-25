import http from 'k6/http';
import {sleep} from 'k6';

const endpoint = 'https://google.com'

export const options = {
  // Key configurations for spike in this section
  stages: [
    { duration: '1m', target: 20 }, // fast ramp-up to a high point
    // No plateau
    { duration: '10s', target: 0 }, // quick ramp-down to 0 users
  ],
};

export default () => {
  const urlRes = http.get(endpoint);
};