const http = require('http');
const { exec } = require('child_process');

// Configuration variables
const email = 'riandyhsn@gmail.com';
const password = 'babiguling123';
const baseUrl = 'https://api.antrein13.cloud';
const be_mode = 'bc'; // replace with actual be_mode
const k6Script = 'k6-backend.js';

// Function to login and retrieve the token
function login(callback) {
  const loginData = JSON.stringify({
    email: email,
    password: password,
  });

  const options = {
    hostname: 'api.antrein13.cloud',
    path: `/${be_mode}/dashboard/auth/login`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': loginData.length,
    },
  };

  const req = http.request(options, (res) => {
    let data = '';

    res.on('data', (chunk) => {
      data += chunk;
    });
    
    res.on('end', () => {
      console.log(data)
      const response = JSON.parse(data);
      if (response.data && response.data.token) {
        callback(null, response.data.token);
      } else {
        callback('Login failed');
      }
    });
  });

  req.on('error', (e) => {
    callback(`Problem with request: ${e.message}`);
  });

  req.write(loginData);
  req.end();
}

// Function to run k6 test with the retrieved token
function runK6Test(token) {
  const command = `k6 run ${k6Script} --vus 10 --duration 30s --out json=test-result.json -e TOKEN=${token}`;
  
  exec(command, (error, stdout, stderr) => {
    if (error) {
      console.error(`exec error: ${error}`);
      return;
    }
    console.log(`stdout: ${stdout}`);
    console.error(`stderr: ${stderr}`);
  });
}

// Main script execution
login((error, token) => {
  if (error) {
    console.error(`Login error: ${error}`);
    return;
  }

  console.log(`Login successful. Token: ${token}`);
  runK6Test(token);
});
