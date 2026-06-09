const crypto = require('crypto');

const whatsappVerificationService = require('../services/whatsappVerificationService');
const { maskPhoneNumber } = require('../utils/authUtils');

const isPlaceholderSecret = (value) =>
  /your-|replace_|paste_|example|placeholder/i.test(String(value || ''));

const verifyMetaWebhookSignature = (req) => {
  const appSecret = String(process.env.WHATSAPP_APP_SECRET || '').trim();

  if (!appSecret || isPlaceholderSecret(appSecret)) {
    return process.env.NODE_ENV !== 'production';
  }

  const suppliedSignature = String(req.get('x-hub-signature-256') || '').trim();
  const rawBody = req.rawBody;

  if (!suppliedSignature.startsWith('sha256=') || !Buffer.isBuffer(rawBody)) {
    return false;
  }

  const expectedSignature = `sha256=${crypto
    .createHmac('sha256', appSecret)
    .update(rawBody)
    .digest('hex')}`;
  const suppliedBuffer = Buffer.from(suppliedSignature);
  const expectedBuffer = Buffer.from(expectedSignature);

  return (
    suppliedBuffer.length === expectedBuffer.length &&
    crypto.timingSafeEqual(suppliedBuffer, expectedBuffer)
  );
};

const extractIncomingMessages = (payload) => {
  const entries = Array.isArray(payload?.entry) ? payload.entry : [];
  const messages = [];

  for (const entry of entries) {
    const changes = Array.isArray(entry?.changes) ? entry.changes : [];

    for (const change of changes) {
      const value = change?.value ?? {};
      const incomingMessages = Array.isArray(value.messages) ? value.messages : [];

      for (const message of incomingMessages) {
        const body = message?.text?.body;
        const senderPhoneNumber = message?.from;

        if (!body || !senderPhoneNumber) {
          continue;
        }

        messages.push({
          body: String(body),
          senderPhoneNumber: String(senderPhoneNumber),
        });
      }
    }
  }

  return messages;
};

const processIncomingMessages = async (messages, startTime) => {
  for (const message of messages) {
    console.log(`[WEBHOOK] Sender: ${message.senderPhoneNumber}`);
    console.log(`[WEBHOOK] Raw text body: ${message.body}`);
    
    const token = whatsappVerificationService.extractVerificationToken(message.body);

    if (!token) {
      console.log('[WEBHOOK] DB lookup: not_found');
      console.log('[WEBHOOK] No valid token found');
      continue;
    }

    console.log(`[WEBHOOK] Normalized token: ${token}`);

    try {
      const result = await whatsappVerificationService.verifyIncomingWhatsappToken({
        token,
        senderPhoneNumber: message.senderPhoneNumber,
      });

      if (result && result.verified) {
        console.log(`[WEBHOOK] Verification updated: verificationId=${result.verificationId}`);
        if (result.userId && result.userId !== 'none') {
          console.log(`[WEBHOOK] User activation updated: userId=${result.userId}`);
        }
      }
    } catch (error) {
      console.error('[webhook] WhatsApp verification processing failed:', error);
    }
  }
  console.log(`[WEBHOOK] Completed in ${Date.now() - startTime}ms`);
};

const verifyWebhookHandler = (req, res) => {
  const mode = req.query['hub.mode'];
  const verifyToken = req.query['hub.verify_token'];
  const challenge = req.query['hub.challenge'];

  if (
    mode === 'subscribe' &&
    verifyToken &&
    verifyToken === process.env.WHATSAPP_VERIFY_TOKEN
  ) {
    return res.status(200).send(challenge ?? '');
  }

  return res.sendStatus(403);
};

const receiveWebhookHandler = (req, res) => {
  const startTime = Date.now();
  console.log('[WEBHOOK] Event received');
  
  if (!verifyMetaWebhookSignature(req)) {
    return res.status(401).json({
      success: false,
      message: 'Invalid WhatsApp webhook signature.',
      code: 'invalid_webhook_signature',
    });
  }

  const messages = extractIncomingMessages(req.body);
  console.log(`[WEBHOOK] Message count: ${messages.length}`);

  res.status(200).json({ success: true });

  if (messages.length === 0) {
    console.log(`[WEBHOOK] Completed in ${Date.now() - startTime}ms`);
    return;
  }

  setImmediate(() => {
    processIncomingMessages(messages, startTime).catch((error) => {
      console.error('[webhook] WhatsApp webhook background processing failed:', error);
    });
  });
};

module.exports = {
  extractIncomingMessages,
  processIncomingMessages,
  receiveWebhookHandler,
  verifyMetaWebhookSignature,
  verifyWebhookHandler,
};
