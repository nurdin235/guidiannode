const crypto = require('crypto');
const http = require('http');
const https = require('https');
const path = require('path');

// Load env configuration
require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const token = process.argv[2] || 'CM-27 LEG';
const baseUrl = process.argv[3] || 'http://localhost:3000';
const senderPhone = process.argv[4] || '237657262038';

const payload = {
  entry: [
    {
      changes: [
        {
          value: {
            messages: [
              {
                from: senderPhone,
                type: 'text',
                text: {
                  body: token
                }
              }
            ]
          }
        }
      ]
    }
  ]
};

const payloadString = JSON.stringify(payload);
const appSecret = String(process.env.WHATSAPP_APP_SECRET || '').trim();

let signature = '';
if (appSecret) {
  signature = 'sha256=' + crypto
    .createHmac('sha256', appSecret)
    .update(payloadString)
    .digest('hex');
  console.log(`[test-webhook] Calculated HMAC Signature: ${signature}`);
} else {
  console.log('[test-webhook] WARNING: WHATSAPP_APP_SECRET not found in .env. Running without valid signature check.');
}

console.log(`[test-webhook] Target URL: ${baseUrl}/webhook`);
console.log(`[test-webhook] Simulating payload token: "${token}"`);
console.log(`[test-webhook] Sender phone: "${senderPhone}"`);

const urlObj = new URL(`${baseUrl}/webhook`);
const client = urlObj.protocol === 'https:' ? https : http;

const options = {
  hostname: urlObj.hostname,
  port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
  path: urlObj.pathname + urlObj.search,
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payloadString),
    ...(signature ? { 'x-hub-signature-256': signature } : {})
  }
};

const req = client.request(options, (res) => {
  console.log(`[test-webhook] Webhook response status: ${res.statusCode}`);
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    console.log('[test-webhook] Webhook response body:');
    try {
      console.log(JSON.stringify(JSON.parse(data), null, 2));
    } catch {
      console.log(data);
    }
  });
});

req.on('error', (e) => {
  console.error(`[test-webhook] Request failed: ${e.message}`);
});

req.write(payloadString);
req.end();
