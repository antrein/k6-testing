const express = require('express');
const bodyParser = require('body-parser');
const { exec } = require('child_process');
const fs = require('fs');
const path = require('path');
const { google } = require('googleapis');
const moment = require('moment-timezone');

const app = express();
const port = 3001;

app.use(bodyParser.json());

async function getSheetsClient() {
  const auth = new google.auth.GoogleAuth({
    keyFile: './gcp.json', // Replace with the path to your service account key file
    scopes: ['https://www.googleapis.com/auth/spreadsheets'],
  });

  const authClient = await auth.getClient();
  return google.sheets({ version: 'v4', auth: authClient });
}

app.post('/run', (req, res) => {
  const { vus_per_endpoint, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode } = req.body;

  if (!vus_per_endpoint || !endpoints || !Array.isArray(endpoints) || !platform || !nodes || !cpu || !memory || !infra_mode || !be_mode) {
    return res.status(400).send('Required parameters: vus, endpoints, platform, nodes, cpu, memory, infra_mode, be_mode');
  }

  const k6ScriptPath = path.join(__dirname, 'k6-scenario.js');
  const tempScriptPath = path.join(__dirname, 'temp_k6.js');

  // Read the k6 script template
  let k6Script = fs.readFileSync(k6ScriptPath, 'utf8');

  // Replace placeholders with actual values
  k6Script = k6Script.replace('__ENDPOINTS__', JSON.stringify(endpoints));
  k6Script = k6Script.replace('__VUS__', vus_per_endpoint);

  // Write the modified script to a temporary file
  fs.writeFileSync(tempScriptPath, k6Script);

  // Capture the start time
  const startTime = moment().utc().format();

  // Define the log file path
  const logFilePath = path.join(__dirname, 'k6-error-logs.txt');

  // Execute the k6 test using the generated script and save output as JSON, capturing stderr
  exec(`k6 run ${tempScriptPath} --summary-export output.json 2>> ${logFilePath}`, { maxBuffer: 1024 * 1024 * 20 }, async (error, stdout, stderr) => {
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
    });
  });
});

app.listen(port, () => {
  console.log(`API server running at http://localhost:${port}`);
});
