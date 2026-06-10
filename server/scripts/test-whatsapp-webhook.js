const crypto = require('crypto');
const path = require('path');

require('dotenv').config({ path: path.resolve(__dirname, '../.env') });

const { normalizeVerificationToken } = require('../services/whatsappVerificationService');

const args = process.argv.slice(2);

const readArg = (names, fallback = undefined) => {
  for (let index = 0; index < args.length; index += 1) {
    const arg = args[index];
    const matchedName = names.find((name) => arg === name || arg.startsWith(`${name}=`));

    if (!matchedName) {
      continue;
    }

    if (arg.includes('=')) {
      return arg.slice(arg.indexOf('=') + 1);
    }

    return args[index + 1] ?? fallback;
  }

  return fallback;
};

const hasFlag = (name) => args.includes(name);

const normalizeBaseUrl = (value) => String(value || '').replace(/\/+$/, '');

const baseUrl = normalizeBaseUrl(
  readArg(['--base-url', '--url'], process.env.API_BASE_URL || 'http://localhost:3000')
);
const senderPhone = readArg(['--sender', '--sender-phone'], '237657262038');

let verificationId = readArg(['--verification-id', '--id']);
let token = readArg(['--token']);
let messageBody = readArg(['--body', '--message']);

const buildSpacedTokenMessage = (value) => {
  const normalized = normalizeVerificationToken(value);

  if (!normalized) {
    return value;
  }

  return normalized.replace(/^CM-([A-Z0-9]{2})([A-Z0-9]{3})$/, 'CM-$1 $2');
};

const printUsageAndExit = () => {
  console.error(
    [
      'Usage:',
      '  node scripts/test-whatsapp-webhook.js --verification-id <uuid> --token <CM-XXXXX> [--base-url <url>]',
      '  node scripts/test-whatsapp-webhook.js --start-register --phone <phone> [--base-url <url>]',
      '',
      'Optional:',
      '  --body "CM-27 LEG"      Message body sent to /webhook.',
      '  --body-spaced          Send the generated token with an internal space.',
      '  --sender 237657262038  Simulated WhatsApp sender phone.',
    ].join('\n')
  );
  process.exit(1);
};

const buildRegistrationPayload = () => ({
  full_name: readArg(['--name'], 'Webhook Test User'),
  phone_number: readArg(['--phone'], senderPhone),
  quarter: readArg(['--quarter'], 'Test Quarter'),
  location_permission: false,
  emergency_contact: {
    contact_name: readArg(['--contact-name'], 'Webhook Test Contact'),
    phone_number: readArg(['--contact-phone'], senderPhone),
    relationship: readArg(['--relationship'], 'Friend'),
  },
});

const parseJsonResponse = async (response) => {
  const text = await response.text();
  if (!text) {
    return {};
  }

  try {
    return JSON.parse(text);
  } catch {
    return { raw: text };
  }
};

const postJson = async (url, body, headers = {}) => {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: JSON.stringify(body),
  });
  const data = await parseJsonResponse(response);
  return { response, data };
};

const getJson = async (url) => {
  const response = await fetch(url);
  const data = await parseJsonResponse(response);
  return { response, data };
};

const signPayload = (payloadString) => {
  const appSecret = String(process.env.WHATSAPP_APP_SECRET || '').trim();

  if (!appSecret) {
    return null;
  }

  return `sha256=${crypto
    .createHmac('sha256', appSecret)
    .update(payloadString)
    .digest('hex')}`;
};

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const pollVerificationStatus = async () => {
  let lastStatus = null;

  for (let attempt = 1; attempt <= 12; attempt += 1) {
    const { response, data } = await getJson(
      `${baseUrl}/api/verification/status/${verificationId}`
    );
    lastStatus = { httpStatus: response.status, data };

    const status = data.status;
    const verified = data.verified === true || status === 'verified';
    if (verified || status === 'expired' || status === 'failed') {
      return lastStatus;
    }

    await sleep(1000);
  }

  return lastStatus;
};

const main = async () => {
  if (hasFlag('--help') || !baseUrl) {
    printUsageAndExit();
  }

  if ((!verificationId || !token) && hasFlag('--start-register')) {
    const registrationPayload = buildRegistrationPayload();
    const { response, data } = await postJson(
      `${baseUrl}/api/auth/register/start-verification`,
      registrationPayload
    );

    if (!response.ok || data.success !== true) {
      console.error('[test-webhook] start-verification failed');
      console.error(JSON.stringify(data, null, 2));
      process.exit(1);
    }

    verificationId = data.verificationId;
    token = data.token;
    console.log(`[test-webhook] Created pending verificationId=${verificationId}`);
  }

  if (!verificationId || !token) {
    printUsageAndExit();
  }

  messageBody = messageBody || (hasFlag('--body-spaced') ? buildSpacedTokenMessage(token) : token);
  const normalizedToken = normalizeVerificationToken(messageBody);

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
                    body: messageBody,
                  },
                },
              ],
            },
          },
        ],
      },
    ],
  };

  const payloadString = JSON.stringify(payload);
  const signature = signPayload(payloadString);

  console.log(`[test-webhook] baseUrl=${baseUrl}`);
  console.log(`[test-webhook] verificationId=${verificationId}`);
  console.log(`[test-webhook] messageBody=${messageBody}`);
  console.log(`[test-webhook] normalizedToken=${normalizedToken ?? 'none'}`);

  const { response: webhookResponse, data: webhookData } = await postJson(
    `${baseUrl}/webhook`,
    payload,
    signature ? { 'x-hub-signature-256': signature } : {}
  );

  console.log(`[test-webhook] webhookHttpStatus=${webhookResponse.status}`);
  if (!webhookResponse.ok) {
    console.error('[test-webhook] webhook failed');
    console.error(JSON.stringify(webhookData, null, 2));
    process.exit(1);
  }

  const statusResult = await pollVerificationStatus();
  const statusData = statusResult?.data ?? {};
  const verified = statusData.verified === true || statusData.status === 'verified';

  console.log(
    `[test-webhook] statusEndpoint httpStatus=${statusResult?.httpStatus} status=${statusData.status} verified=${statusData.verified}`
  );
  console.log(
    `[test-webhook] session=${statusData.session ? 'present' : 'missing'} authToken=${
      statusData.authToken ? 'present' : 'missing'
    } user=${statusData.user ? 'present' : 'missing'}`
  );

  if (normalizedToken && verified) {
    console.log('VERIFIED');
    return;
  }

  console.error('FAILED');
  process.exit(1);
};

main().catch((error) => {
  console.error(`[test-webhook] FAILED: ${error.message}`);
  process.exit(1);
});
