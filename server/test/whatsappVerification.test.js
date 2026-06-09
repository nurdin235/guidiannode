const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const test = require('node:test');

process.env.JWT_SECRET ||= 'test_jwt_secret_with_enough_length_for_unit_tests';
process.env.SUPABASE_URL ||= 'https://example.supabase.co';
process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test_service_role_key';
process.env.WHATSAPP_BUSINESS_NUMBER ||= '237657262038';

const {
  buildWhatsappUrl,
  extractVerificationToken,
} = require('../services/whatsappVerificationService');
const {
  extractIncomingMessages,
  verifyMetaWebhookSignature,
} = require('../controllers/whatsappWebhookController');

test('extractVerificationToken finds and normalizes GuardianNode WhatsApp tokens', () => {
  assert.equal(extractVerificationToken('please verify cm-a7k9q'), 'CM-A7K9Q');
  assert.equal(extractVerificationToken('Token: CM-3F8XZ. Thank you'), 'CM-3F8XZ');
  assert.equal(extractVerificationToken('hello without token'), null);
  
  // Spaced and tolerant variations
  assert.equal(extractVerificationToken('CM-27LEG'), 'CM-27LEG');
  assert.equal(extractVerificationToken('cm-27leg'), 'CM-27LEG');
  assert.equal(extractVerificationToken('CM-27 LEG'), 'CM-27LEG');
  assert.equal(extractVerificationToken('CM 27LEG'), 'CM-27LEG');
  assert.equal(extractVerificationToken('CM 27 LEG'), 'CM-27LEG');
  assert.equal(extractVerificationToken('hello CM-27 LEG thanks'), 'CM-27LEG');
});

test('buildWhatsappUrl uses wa.me business number format', () => {
  assert.equal(
    buildWhatsappUrl('CM-Q2LMP'),
    'https://wa.me/237657262038?text=CM-Q2LMP'
  );
});

test('extractIncomingMessages safely walks WhatsApp Cloud API payloads', () => {
  const payload = {
    entry: [
      {
        changes: [
          {
            value: {
              messages: [
                {
                  from: '237657262038',
                  text: { body: 'CM-A7K9Q' },
                },
                {
                  from: '237657262038',
                },
              ],
            },
          },
        ],
      },
    ],
  };

  assert.deepEqual(extractIncomingMessages(payload), [
    {
      senderPhoneNumber: '237657262038',
      body: 'CM-A7K9Q',
    },
  ]);
  assert.deepEqual(extractIncomingMessages({}), []);
});

test('verifyMetaWebhookSignature validates Meta HMAC signatures', () => {
  const originalSecret = process.env.WHATSAPP_APP_SECRET;
  const originalNodeEnv = process.env.NODE_ENV;
  const appSecret = 'unit_test_meta_app_secret';
  const rawBody = Buffer.from('{"entry":[]}');
  const signature = `sha256=${crypto
    .createHmac('sha256', appSecret)
    .update(rawBody)
    .digest('hex')}`;

  process.env.NODE_ENV = 'production';
  process.env.WHATSAPP_APP_SECRET = appSecret;

  try {
    assert.equal(
      verifyMetaWebhookSignature({
        rawBody,
        get: () => signature,
      }),
      true
    );
    assert.equal(
      verifyMetaWebhookSignature({
        rawBody,
        get: () => 'sha256=invalid',
      }),
      false
    );
  } finally {
    process.env.NODE_ENV = originalNodeEnv;
    process.env.WHATSAPP_APP_SECRET = originalSecret;
  }
});
