const crypto = require('crypto');
const http = require('http');
const https = require('https');
require('dotenv').config({ path: require('path').resolve(__dirname, '../.env') });

const token = process.argv[2] || 'CM-27LEG';
const baseUrl = process.argv[3] || 'http://localhost:3000';
const senderPhone = process.argv[4] || '237657262038';

const payload = {
  object: 'whatsapp_business_account',
  entry: [
    {
      id: 'WHATSAPP_BUSINESS_ACCOUNT_ID',
      changes: [
        {
          value: {
            messaging_product: 'whatsapp',
            metadata: {
              display_phone_number: '16505553333',
              phone_number_id: '10222625262038'
            },
            contacts: [
              {
                profile: {
                  name: 'Test User'
                },
                wa_id: senderPhone
              }
            ],
            messages: [
              {
                from: senderPhone,
                id: 'wamid.HBgLMjM3NjU3MjYyMDM4FQIAERgSQjE4RDREMzgxQUFCMjVDRjNBAA==',
                timestamp: Math.round(Date.now() / 1000).toString(),
                text: {
                  body: token
                },
                type: 'text'
              }
            ]
          },
          field: 'messages'
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
  console.log(`[test] Computed signature: ${signature}`);
} else {
  console.log('[test] WHATSAPP_APP_SECRET not found in .env; signature verification may fail if running in production.');
}

console.log(`[test] Sending payload to ${baseUrl}/webhook...`);
console.log(`[test] Payload token: ${token}`);
console.log(`[test] Sender phone: ${senderPhone}`);

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
  console.log(`[test] Response status: ${res.statusCode}`);
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  res.on('end', () => {
    console.log('[test] Response body:');
    try {
      console.log(JSON.stringify(JSON.parse(data), null, 2));
    } catch {
      console.log(data);
    }
  });
});

req.on('error', (e) => {
  console.error(`[test] Error sending request: ${e.message}`);
});

req.write(payloadString);
req.end();
