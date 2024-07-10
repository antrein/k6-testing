const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const moment = require('moment-timezone');

const app = express();
const port = 3003;

const SHEET_ID = '1qtKIWwuslWP9ICPOF0Kkx74gdTuytFeWJn6gg2iBwsY'; // Replace with your Google Sheet ID

app.use(bodyParser.json());

async function getSheetsClient() {
  const auth = new google.auth.GoogleAuth({
    keyFile: './gcp.json', // Replace with the path to your service account key file
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  });

  const authClient = await auth.getClient();
  return google.sheets({ version: 'v4', auth: authClient });
}

app.post('/test1', (req, res) => {
  const { vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token } = req.body;

  if (!vus_per_endpoint || !endpoints || !Array.isArray(endpoints) || !platform || !nodes || !cpu || !memory || !infra_mode || !be_mode || !token) {
    return res.status(400).send('Required parameters: vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token');
  }

  const k6ScriptPath = path.join(__dirname, 'be-k6.js');
  const tempScriptPath = path.join(__dirname, 'temp_k6_backend_1.js');

  // Read the k6 script template
  let k6Script = fs.readFileSync(k6ScriptPath, 'utf8');

  // Replace placeholders with actual values
  const project_id = endpoints[0].match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1]; // Extract project_id from the first endpoint
  const baseEndpoint = `https://api.antrein14.cloud/${be_mode}/dashboard/project/detail/${project_id}`;
  k6Script = k6Script.replace('__ENDPOINT__', JSON.stringify(baseEndpoint));
  k6Script = k6Script.replace('__TOKEN__', token);
  k6Script = k6Script.replace('__VUS__', vus_per_endpoint);
  k6Script = k6Script.replace('__METHOD__', 'GET');
  k6Script = k6Script.replace('__REQUEST_BODY__', '');

  // Write the modified script to a temporary file
  fs.writeFileSync(tempScriptPath, k6Script);

  executeK6Test(tempScriptPath, res, infra_mode, be_mode, platform, nodes, cpu, memory, endpoints, vus_per_endpoint, 1);
});

app.post('/test2', (req, res) => {
  const { vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token } = req.body;

  if (!vus_per_endpoint || !endpoints || !Array.isArray(endpoints) || !platform || !nodes || !cpu || !memory || !infra_mode || !be_mode || !token) {
    return res.status(400).send('Required parameters: vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token');
  }

  const k6ScriptPath = path.join(__dirname, 'be-k6.js');
  const tempScriptPath = path.join(__dirname, 'temp_k6_backend_2.js');

  // Read the k6 script template
  let k6Script = fs.readFileSync(k6ScriptPath, 'utf8');

  // Replace placeholders with actual values
  const project_id = endpoints[0].match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1]; // Extract project_id from the first endpoint
  const baseEndpoint = `https://api.antrein14.cloud/${be_mode}/dashboard/analytic?project_id=${project_id}`;
  k6Script = k6Script.replace('__ENDPOINT__', JSON.stringify(baseEndpoint));
  k6Script = k6Script.replace('__TOKEN__', token);
  k6Script = k6Script.replace('__VUS__', vus_per_endpoint);
  k6Script = k6Script.replace('__METHOD__', 'GET');
  k6Script = k6Script.replace('__REQUEST_BODY__', '');

  // Write the modified script to a temporary file
  fs.writeFileSync(tempScriptPath, k6Script);

  executeK6Test(tempScriptPath, res, infra_mode, be_mode, platform, nodes, cpu, memory, endpoints, vus_per_endpoint, 2);
});

app.post('/test3', (req, res) => {
  const { vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token } = req.body;

  if (!vus_per_endpoint || !endpoints || !Array.isArray(endpoints) || !platform || !nodes || !cpu || !memory || !infra_mode || !be_mode || !token) {
    return res.status(400).send('Required parameters: vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode, token');
  }

  const k6ScriptPath = path.join(__dirname, 'be-k6.js');
  const tempScriptPath = path.join(__dirname, 'temp_k6_backend_3.js');

  // Read the k6 script template
  let k6Script = fs.readFileSync(k6ScriptPath, 'utf8');

  // Replace placeholders with actual values
  const project_id = endpoints[0].match(/https:\/\/(?:.*\.)?(.+)\.antrein\d*\.cloud/)[1]; // Extract project_id from the first endpoint
  const baseEndpoint = `https://api.antrein14.cloud/${be_mode}/dashboard/auth/login`;
  k6Script = k6Script.replace('__ENDPOINT__', JSON.stringify(baseEndpoint));
  k6Script = k6Script.replace('__TOKEN__', token);
  k6Script = k6Script.replace('__VUS__', vus_per_endpoint);
  k6Script = k6Script.replace('__METHOD__', 'POST');
  k6Script = k6Script.replace('__REQUEST_BODY__', JSON.stringify({ email: "riandyhsn@gmail.com", password: "babiguling123" }));

  // Write the modified script to a temporary file
  fs.writeFileSync(tempScriptPath, k6Script);

  executeK6Test(tempScriptPath, res, infra_mode, be_mode, platform, nodes, cpu, memory, endpoints, vus_per_endpoint, 3);
});

function executeK6Test(tempScriptPath, res, infra_mode, be_mode, platform, nodes, cpu, memory, endpoints, vus_per_endpoint, scenario) {
  // Capture the start time
  const startTime = moment().utc().format();

  // Define the log file path
  const logFilePath = path.join(__dirname, 'k6-error-logs.txt');

  // Execute the k6 test using the generated script and save output as JSON, capturing stderr
  exec(`k6 run ${tempScriptPath} --summary-export output.json 2>> ${logFilePath}`, { maxBuffer: 1024 * 1024 * 20 }, async (error, stdout, stderr) => {
    // Capture the end time
    const endTime = moment().utc().format();

    // Clean up the temporary script file
    fs.unlinkSync(tempScriptPath);

    if (error) {
      console.error(`exec error: ${error}`);
      return res.status(500).send(`Error running k6: ${error}`);
    }

    console.log(`stdout: ${stdout}`);
    console.error(`stderr: ${stderr}`);

    // Read the JSON output and upload necessary data to Google Sheets
    fs.readFile('output.json', 'utf8', async (err, data) => {
      if (err) {
        console.error(`readFile error: ${err}`);
        return res.status(500).send(`Error reading output file: ${err}`);
      }

      const output = JSON.parse(data);
      const metrics = output.metrics;
      const totalRequests = metrics['http_reqs'].count;
      const failedRequests = metrics['http_req_failed'].passes;
      const successRate = ((totalRequests - failedRequests) / totalRequests) * 100;
      const httpReqDurationAvgSuccess = metrics['http_req_duration_success'] ? metrics['http_req_duration_success'].avg : 0;
      const httpReqDurationAvgFail = metrics['http_req_duration_fail'] ? metrics['http_req_duration_fail'].avg : 0;
      const virtualUsers = metrics['iterations'].count; // Get the number of virtual users
      const numProjects = endpoints.length;

      // Convert start and end times to Jakarta time and strip timezone
      const startTimestampJakarta = moment(startTime).tz('Asia/Jakarta').format('YYYY-MM-DDTHH:mm:ss');
      const endTimestampJakarta = moment(endTime).tz('Asia/Jakarta').format('YYYY-MM-DDTHH:mm:ss');

      // Run monitoring.sh to get max CPU and memory usage
      exec(`sh prometheus.sh ${startTime} ${endTime}`, async (monError, monStdout, monStderr) => {
        if (monError) {
          console.error(`Monitoring script error: ${monError}`);
          return res.status(500).send(`Error running monitoring script: ${monError}`);
        }

        const [maxCpu, maxMemory] = monStdout.trim().split('\n').map(line => line.split(': ')[1]);

        try {
          const sheets = await getSheetsClient();
          const values = [
            [startTimestampJakarta, endTimestampJakarta, infra_mode, be_mode, platform, nodes, cpu, memory, numProjects, vus_per_endpoint, virtualUsers, successRate.toFixed(2), httpReqDurationAvgSuccess, httpReqDurationAvgFail, maxCpu, maxMemory],
          ];

          const resource = {
            values,
          };

          sheets.spreadsheets.values.append(
            {
              spreadsheetId: SHEET_ID,
              range: `be_${be_mode}_${scenario}!A1`,
              valueInputOption: 'RAW',
              resource,
            },
            (err, result) => {
              if (err) {
                console.error(`Google Sheets API error: ${err}`);
                return res.status(500).send(`Error updating Google Sheet: ${err}`);
              } else {
                console.log(`${result.data.updates.updatedCells} cells updated.`);
                res.status(200).send('Test completed and data uploaded to Google Sheets.');
              }
            }
          );
        } catch (err) {
          console.error(`Google Sheets API error: ${err}`);
          return res.status(500).send(`Error authenticating with Google Sheets: ${err}`);
        }
      });
    });
  });
}

app.listen(port, () => {
  console.log(`API server running at http://localhost:${port}`);
});