const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const moment = require('moment-timezone');

const app = express();
const port = 3001; // Ensure this port is available and not used by any other service

const SHEET_ID = '1qtKIWwuslWP9ICPOF0Kkx74gdTuytFeWJn6gg2iBwsY'; // Replace with your Google Sheet ID

app.use(bodyParser.json());

app.post('/test', (req, res) => {
  const { vus, endpoint } = req.body;

  if (!vus || !endpoint) {
    return res.status(400).send('Missing parameters: vus and endpoint are required.');
  }

  const k6ScriptPath = path.join(__dirname, 'k6-poc.js');
  const tempScriptPath = path.join(__dirname, 'temp_k6_script.js');

  // Determine the sheet name based on the endpoint
  const sheetName = endpoint.includes('antrein') ? 'poc_with_antrein' : 'poc_without_antrein';

  // Read the k6 script template
  let k6Script = fs.readFileSync(k6ScriptPath, 'utf8');

  // Replace placeholders with actual values
  k6Script = k6Script.replace('__VUS__', vus).replace('__ENDPOINT__', endpoint);

  // Write the modified script to a temporary file
  fs.writeFileSync(tempScriptPath, k6Script);

  // Execute the k6 test using the generated script and save output as JSON
  exec(`k6 run ${tempScriptPath} --summary-export output.json`, async (error, stdout, stderr) => {
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

      // Get the current timestamp in Jakarta timezone
      const timestamp = moment().tz('Asia/Jakarta').format();

      try {
        const sheets = await getSheetsClient();
        const values = [
          [timestamp, virtualUsers, successRate.toFixed(2), httpReqDurationAvgSuccess, httpReqDurationAvgFail],
        ];

        const resource = {
          values,
        };

        sheets.spreadsheets.values.append(
          {
            spreadsheetId: SHEET_ID,
            range: `${sheetName}!A1`,
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

async function getSheetsClient() {
  const auth = new google.auth.GoogleAuth({
    keyFile: './gcp.json', // Replace with the path to your service account key file
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  });

  const authClient = await auth.getClient();
  return google.sheets({ version: 'v4', auth: authClient });
}

app.listen(port, () => {
  console.log(`API server running at http://localhost:${port}`);
});
