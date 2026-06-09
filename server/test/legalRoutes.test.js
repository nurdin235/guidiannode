const assert = require('node:assert/strict');
const test = require('node:test');

const legalRoutes = require('../routes/legalRoutes');

const getRouteHandler = (path) => {
  const layer = legalRoutes.stack.find(
    (candidate) =>
      candidate.route?.path === path &&
      candidate.route?.methods?.get === true
  );

  return layer?.route?.stack?.[0]?.handle;
};

const invokeHandler = (handler) => {
  const response = {
    statusCode: null,
    headers: {},
    body: '',
    status(code) {
      this.statusCode = code;
      return this;
    },
    set(headers) {
      Object.assign(this.headers, headers);
      return this;
    },
    type(value) {
      this.headers['Content-Type'] = value;
      return this;
    },
    send(body) {
      this.body = body;
      return this;
    },
  };

  handler({}, response);
  return response;
};

test('privacy policy is public HTML with required disclosures', () => {
  const handler = getRouteHandler('/privacy-policy');
  assert.equal(typeof handler, 'function');

  const response = invokeHandler(handler);

  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['Content-Type'], 'html');
  assert.match(response.body, /Guardian Node/);
  assert.match(response.body, /guardian-node-logo\.png/);
  assert.match(response.body, /alt="Guardian Node logo"/);
  assert.match(response.body, /WhatsApp Cloud API and Meta/);
  assert.match(response.body, /verification token/i);
  assert.match(response.body, /emergency alert/i);
  assert.match(response.body, /Bamenda, Cameroon/);
  assert.match(response.body, /https:\/\/wa\.me\/237657262038/);
  assert.match(response.body, /June 6, 2026/);
});

test('data deletion page provides clear public request instructions', () => {
  const handler = getRouteHandler('/data-deletion');
  assert.equal(typeof handler, 'function');

  const response = invokeHandler(handler);

  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['Content-Type'], 'html');
  assert.match(response.body, /registered phone number/i);
  assert.match(response.body, /delete or anonymize/i);
  assert.match(response.body, /security, fraud and abuse prevention/i);
  assert.match(response.body, /Guardian Node Data Deletion Request/);
  assert.match(response.body, /guardian-node-logo\.png/);
  assert.match(response.body, /within 30 days/i);
  assert.match(response.body, /https:\/\/wa\.me\/237657262038/);
  assert.match(response.body, /June 6, 2026/);
});

test('terms of service is public and links privacy and deletion pages', () => {
  const handler = getRouteHandler('/terms-of-service');
  assert.equal(typeof handler, 'function');

  const response = invokeHandler(handler);

  assert.equal(response.statusCode, 200);
  assert.equal(response.headers['Content-Type'], 'html');
  assert.match(response.body, /Terms of Service/);
  assert.match(response.body, /does not replace police, medical, fire/i);
  assert.match(response.body, /href="\/privacy-policy"/);
  assert.match(response.body, /href="\/data-deletion"/);
  assert.match(response.body, /guardian-node-logo\.png/);
});
