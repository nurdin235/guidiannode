const express = require('express');

const router = express.Router();
const DEFAULT_WHATSAPP_NUMBER = '237657262038';
const configuredWhatsappNumber = String(
  process.env.WHATSAPP_TARGET_NUMBER || DEFAULT_WHATSAPP_NUMBER
).replace(/\D/g, '');
const CONTACT_WHATSAPP_NUMBER =
  configuredWhatsappNumber || DEFAULT_WHATSAPP_NUMBER;
const CONTACT_WHATSAPP_DISPLAY = `+${CONTACT_WHATSAPP_NUMBER}`;
const CONTACT_WHATSAPP_URL = `https://wa.me/${CONTACT_WHATSAPP_NUMBER}`;
const DELETION_WHATSAPP_URL =
  `${CONTACT_WHATSAPP_URL}?text=` +
  encodeURIComponent('Guardian Node Data Deletion Request');
const LAST_UPDATED = 'June 6, 2026';

const renderPage = ({ title, summary, content }) => `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>${title} | Guardian Node</title>
  <style>
    :root {
      color: #12233f;
      background: #f4f7fb;
      font-family: Arial, Helvetica, sans-serif;
      line-height: 1.6;
    }
    * { box-sizing: border-box; }
    body { margin: 0; background: #f4f7fb; color: #12233f; }
    header { background: #0e3b82; color: #fff; }
    .header-inner, main, footer {
      width: min(880px, calc(100% - 32px));
      margin: 0 auto;
    }
    .header-inner { padding: 40px 0 34px; }
    .brand {
      margin: 0 0 8px;
      font-size: 1rem;
      font-weight: 700;
      letter-spacing: 0;
    }
    h1 { margin: 0; font-size: clamp(2rem, 6vw, 3.25rem); line-height: 1.12; }
    .summary { max-width: 720px; margin: 16px 0 0; color: #e6eefb; font-size: 1.05rem; }
    main { padding: 30px 0 42px; }
    section {
      margin-bottom: 16px;
      padding: 24px;
      background: #fff;
      border: 1px solid #dbe4f1;
      border-radius: 8px;
    }
    h2 { margin: 0 0 12px; color: #0e3b82; font-size: 1.35rem; }
    h3 { margin: 18px 0 6px; font-size: 1.05rem; }
    p { margin: 0 0 12px; }
    p:last-child { margin-bottom: 0; }
    ul, ol { margin: 8px 0 0; padding-left: 24px; }
    li + li { margin-top: 8px; }
    a { color: #075bb5; font-weight: 700; }
    .notice {
      border-left: 4px solid #009639;
      background: #effaf3;
    }
    .updated { color: #52647d; font-size: 0.95rem; }
    footer { padding: 0 0 36px; color: #52647d; font-size: 0.9rem; }
    footer nav { display: flex; flex-wrap: wrap; gap: 16px; }
    @media (max-width: 560px) {
      .header-inner { padding: 30px 0 26px; }
      main { padding-top: 20px; }
      section { padding: 18px; }
    }
  </style>
</head>
<body>
  <header>
    <div class="header-inner">
      <p class="brand">Guardian Node</p>
      <h1>${title}</h1>
      <p class="summary">${summary}</p>
    </div>
  </header>
  <main>
    ${content}
    <p class="updated"><strong>Last updated:</strong> ${LAST_UPDATED}</p>
  </main>
  <footer>
    <nav aria-label="Legal pages">
      <a href="/privacy-policy">Privacy Policy</a>
      <a href="/data-deletion">Data Deletion Instructions</a>
      <a href="${CONTACT_WHATSAPP_URL}">Contact Support on WhatsApp</a>
    </nav>
  </footer>
</body>
</html>`;

const privacyPolicyPage = renderPage({
  title: 'Privacy Policy',
  summary:
    'This policy explains what information Guardian Node handles, why it is needed, how it is protected, and the choices available to users.',
  content: `
    <section class="notice">
      <h2>Privacy at a glance</h2>
      <p>Guardian Node uses personal information only to provide account verification, authentication, safety communication, and emergency alert features. We do not sell personal information.</p>
    </section>

    <section>
      <h2>1. About Guardian Node</h2>
      <p>Guardian Node is a safety and emergency communication application. It helps users create and verify an account, communicate important safety information, send emergency alerts, and coordinate assistance where those features are available.</p>
      <p>Guardian Node is operated for users in Bamenda, Cameroon.</p>
      <p>This policy applies to the Guardian Node mobile application, its backend services, and the public website pages operated for the application.</p>
    </section>

    <section>
      <h2>2. Information we collect</h2>
      <h3>Account and registration information</h3>
      <ul>
        <li>Your phone number and the name, neighborhood, or other profile details submitted during registration.</li>
        <li>Emergency contact information you choose to provide, including a contact name, phone number, and relationship.</li>
        <li>Account identifiers, verification state, account activation state, login sessions, and security-related timestamps.</li>
      </ul>

      <h3>WhatsApp verification information</h3>
      <ul>
        <li>The WhatsApp sender phone number associated with an incoming verification message.</li>
        <li>The short-lived verification token, its protected hash where stored, verification status, expiration time, and verified time.</li>
        <li>Limited message delivery metadata needed to receive, validate, and process the verification message.</li>
      </ul>

      <h3>Safety and emergency information</h3>
      <ul>
        <li>Emergency alert type, status, time, and related incident details when you use emergency features.</li>
        <li>Location information when you grant location permission or use features that require location, such as SOS routing, nearby alerts, maps, or responder guidance.</li>
        <li>Technical and security records needed to operate the service, investigate failures, prevent misuse, and protect users.</li>
      </ul>
    </section>

    <section>
      <h2>3. Why we use this information</h2>
      <p>Guardian Node processes information for the following purposes:</p>
      <ul>
        <li>To verify that a user controls the phone number used to register or sign in.</li>
        <li>To authenticate users, create secure sessions, maintain account activation status, and prevent token reuse or abuse.</li>
        <li>To provide safety communication and emergency alert functionality.</li>
        <li>To route emergency assistance, display relevant incidents, support responders, and notify trusted contacts where enabled.</li>
        <li>To maintain service security, diagnose technical issues, enforce rate limits, and comply with applicable legal obligations.</li>
      </ul>
    </section>

    <section>
      <h2>4. WhatsApp Cloud API and Meta</h2>
      <p>Guardian Node uses the WhatsApp Cloud API for account verification. When you send a verification message, WhatsApp and Meta may process the message and associated metadata as part of transmitting and delivering it. This can include the sender and recipient phone numbers, message identifiers, delivery information, timestamps, and technical metadata.</p>
      <p>Meta processes this information under its own terms and privacy policies. Guardian Node receives only the information delivered through the WhatsApp Cloud API that is needed to recognize the verification token and confirm the sender phone number.</p>
    </section>

    <section>
      <h2>5. How information is stored and protected</h2>
      <p>Guardian Node stores application data in access-controlled backend and database services. The service uses encrypted HTTPS connections, server-side credentials, signed application sessions, short token expiration periods, webhook signature validation, and restricted administrative access.</p>
      <p>Verification tokens are short-lived and are stored as cryptographic hashes rather than reusable plain-text codes in the verification database. Verified and expired tokens cannot be used again. Sensitive backend credentials are not intentionally included in the mobile application.</p>
      <p>No system can guarantee absolute security. We review access and security controls and take reasonable steps to reduce unauthorized access, alteration, disclosure, or loss.</p>
    </section>

    <section>
      <h2>6. Data sharing</h2>
      <p>Information may be processed by service providers that are necessary to operate Guardian Node, including hosting, database, maps, and WhatsApp Cloud API services. Emergency information may also be shared with trusted contacts, nearby responders, or relevant safety participants when a user activates those features.</p>
      <p>We do not sell personal information or share it for unrelated advertising purposes.</p>
    </section>

    <section>
      <h2>7. Retention</h2>
      <p>We retain account and operational information only for as long as reasonably needed to provide the service, protect users, resolve disputes, prevent fraud or abuse, and satisfy legal obligations. Short-lived verification tokens expire automatically. Some security or emergency records may be retained for a limited period when necessary for safety, auditing, or legal compliance.</p>
    </section>

    <section>
      <h2>8. Your choices and deletion rights</h2>
      <p>You may request access, correction, or deletion of your Guardian Node data. To request deletion, follow the instructions on the <a href="/data-deletion">Data Deletion page</a> or contact Guardian Node through <a href="${CONTACT_WHATSAPP_URL}">WhatsApp at ${CONTACT_WHATSAPP_DISPLAY}</a>.</p>
      <p>Where deletion is requested, we will delete or anonymize eligible account and verification information unless limited retention is required for security, fraud prevention, emergency incident integrity, or legal reasons.</p>
    </section>

    <section>
      <h2>9. Contact</h2>
      <p>Questions about this policy or Guardian Node data practices can be sent to Guardian Node through <a href="${CONTACT_WHATSAPP_URL}">WhatsApp at ${CONTACT_WHATSAPP_DISPLAY}</a>.</p>
    </section>
  `,
});

const dataDeletionPage = renderPage({
  title: 'Data Deletion Instructions',
  summary:
    'Guardian Node users can request deletion of their account and associated personal information by following the steps below.',
  content: `
    <section class="notice">
      <h2>How to request deletion</h2>
      <ol>
        <li>Open <a href="${DELETION_WHATSAPP_URL}">Guardian Node support on WhatsApp</a> and send the message <strong>Guardian Node Data Deletion Request</strong>.</li>
        <li>Include the registered phone number for the Guardian Node account, including its country code.</li>
        <li>State clearly that you want the account and associated personal data deleted.</li>
        <li>Respond to any reasonable identity-verification request so we can confirm that the requester controls the account. Do not send passwords, verification tokens, or unnecessary identity documents.</li>
      </ol>
    </section>

    <section>
      <h2>What we will delete or anonymize</h2>
      <p>After validating the request, Guardian Node will delete or anonymize eligible data associated with the account. This may include:</p>
      <ul>
        <li>Account profile and registration information.</li>
        <li>The registered phone number and stored WhatsApp sender phone number.</li>
        <li>Verification sessions, token hashes, verification status, and authentication records that are no longer required for security.</li>
        <li>Emergency contact information supplied by the user.</li>
        <li>Emergency alert or location data that can be removed without harming the integrity of safety, security, or legally required records.</li>
      </ul>
    </section>

    <section>
      <h2>Information that may be retained</h2>
      <p>Some information may be retained or anonymized instead of immediately deleted when retention is reasonably necessary for security, fraud and abuse prevention, emergency incident integrity, dispute resolution, system backups, or compliance with applicable law.</p>
      <p>Any retained information will be limited to what is necessary for the applicable purpose and will not be used for unrelated advertising.</p>
    </section>

    <section>
      <h2>Processing the request</h2>
      <p>We will acknowledge a valid request and complete deletion or anonymization within 30 days after identity verification, unless a longer period is required by law. We may contact you if the registered phone number cannot be located or if additional confirmation is required. Once completed, access to the deleted account may no longer be possible.</p>
    </section>

    <section>
      <h2>Need help?</h2>
      <p>Send questions or deletion requests through <a href="${CONTACT_WHATSAPP_URL}">WhatsApp at ${CONTACT_WHATSAPP_DISPLAY}</a>. You may also review the <a href="/privacy-policy">Guardian Node Privacy Policy</a> for more information about our data practices.</p>
    </section>
  `,
});

const sendHtml = (html) => (req, res) => {
  res
    .status(200)
    .set({
      'Cache-Control': 'public, max-age=3600',
      'Content-Security-Policy':
        "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
    })
    .type('html')
    .send(html);
};

router.get('/privacy-policy', sendHtml(privacyPolicyPage));
router.get('/data-deletion', sendHtml(dataDeletionPage));

module.exports = router;
