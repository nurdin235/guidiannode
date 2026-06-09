const crypto = require('crypto');

const { authConfig } = require('../config/authConfig');
const { OTP_PURPOSE } = require('../constants/otpPurpose');
const { supabaseAdmin } = require('../config/supabaseClient');
const { AppError, wrapDatabaseError } = require('../utils/appError');
const {
  addMinutes,
  hashOtpCode,
  maskPhoneNumber,
  normalizePhoneNumber,
  nowIso,
} = require('../utils/authUtils');

const OTP_SESSIONS_TABLE = 'otp_sessions';
const TOKEN_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const TOKEN_REGEX = /\bCM-[A-Z0-9]{5}\b/i;
const TOKEN_GENERATION_RETRIES = 12;
const WHATSAPP_INBOUND_METHOD = 'whatsapp_inbound';
const getWhatsappBusinessNumber = () => {
  const configuredNumber = String(
    process.env.WHATSAPP_TARGET_NUMBER ||
      process.env.WHATSAPP_BUSINESS_NUMBER ||
      ''
  );
  const digitsOnly = configuredNumber.replace(/\D/g, '');

  if (!digitsOnly) {
    throw new AppError(
      'WhatsApp target number is not configured.',
      500,
      'whatsapp_target_number_missing'
    );
  }

  return digitsOnly;
};

const buildWhatsappUrl = (token) =>
  `https://wa.me/${getWhatsappBusinessNumber()}?text=${encodeURIComponent(token)}`;

const generateWhatsappVerificationToken = () => {
  const bytes = crypto.randomBytes(5);
  const suffix = Array.from(bytes, (byte) => TOKEN_ALPHABET[byte % TOKEN_ALPHABET.length]).join('');

  return `CM-${suffix}`;
};

const extractVerificationToken = (messageBody) => {
  const body = String(messageBody ?? '').trim();
  
  // 1. Try strict match first (case-insensitive word boundaries)
  const strictMatch = body.match(/\bCM-[A-Z0-9]{5}\b/i);
  if (strictMatch) {
    return strictMatch[0].toUpperCase();
  }

  // 2. Try tolerant regex for spaced tokens (e.g. "CM-27 LEG", "CM 27 LEG", "CM 27LEG")
  // C and M with optional spaces, optional separator (hyphen or space), followed by 5 alphanumeric characters (each optionally followed by spaces)
  const tolerantMatch = body.match(/C\s*M\s*[- ]?\s*([A-Z0-9]\s*){5}/i);
  if (tolerantMatch) {
    const clean = tolerantMatch[0].replace(/\s+/g, '').toUpperCase();
    if (clean.startsWith('CM-')) {
      return clean;
    } else if (clean.startsWith('CM')) {
      return 'CM-' + clean.substring(2);
    }
  }

  return null;
};

const isWhatsappVerificationSession = (otpSession) =>
  otpSession?.verification_method === WHATSAPP_INBOUND_METHOD ||
  otpSession?.metadata?.verification_method === WHATSAPP_INBOUND_METHOD;

const isMissingColumnError = (error, columnName) => {
  const haystack = [error?.message, error?.details, error?.hint]
    .filter(Boolean)
    .join(' ')
    .toLowerCase();

  return (
    haystack.includes(String(columnName).toLowerCase()) &&
    (error?.code === 'PGRST204' || haystack.includes('schema cache'))
  );
};

const pendingTokenExists = async (token) => {
  const { data, error } = await supabaseAdmin
    .from(OTP_SESSIONS_TABLE)
    .select('id')
    .eq('status', 'pending')
    .eq('otp_code_hash', hashOtpCode(token))
    .limit(1);

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  return (data ?? []).length > 0;
};

const generateUniqueWhatsappVerificationToken = async () => {
  for (let attempt = 0; attempt < TOKEN_GENERATION_RETRIES; attempt += 1) {
    const token = generateWhatsappVerificationToken();

    if (!(await pendingTokenExists(token))) {
      return token;
    }
  }

  throw new AppError(
    'Unable to create a unique WhatsApp verification token. Please try again.',
    500,
    'whatsapp_token_generation_failed'
  );
};

const cancelPendingVerificationSessions = async ({ phoneNumber, purpose }) => {
  const { error } = await supabaseAdmin
    .from(OTP_SESSIONS_TABLE)
    .update({
      status: 'cancelled',
      updated_at: nowIso(),
    })
    .eq('phone_number', phoneNumber)
    .eq('purpose', purpose)
    .eq('status', 'pending');

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }
};

const createWhatsappVerification = async ({
  phoneNumber,
  purpose,
  pendingUserId = null,
  registrationPayload = null,
}) => {
  const token = await generateUniqueWhatsappVerificationToken();
  const expiresAt = addMinutes(authConfig.otpExpiresMinutes);
  const whatsappUrl = buildWhatsappUrl(token);

  await cancelPendingVerificationSessions({ phoneNumber, purpose });

  const sessionPayload = {
    id: crypto.randomUUID(),
    phone_number: phoneNumber,
    purpose,
    status: 'pending',
    otp_code_hash: hashOtpCode(token),
    expires_at: expiresAt,
    attempts: 0,
    max_attempts: 1,
    pending_user_id: pendingUserId,
    verification_method: WHATSAPP_INBOUND_METHOD,
    registration_payload: registrationPayload,
    metadata: {
      mode: WHATSAPP_INBOUND_METHOD,
      verification_method: WHATSAPP_INBOUND_METHOD,
      token_format: 'CM-XXXXX',
      whatsapp_business_number: getWhatsappBusinessNumber(),
    },
    created_at: nowIso(),
    updated_at: nowIso(),
  };

  const insertSession = (payload) =>
    supabaseAdmin
      .from(OTP_SESSIONS_TABLE)
      .insert(payload)
      .select()
      .single();

  let activePayload = { ...sessionPayload };
  let { data, error } = await insertSession(activePayload);

  for (const optionalColumn of ['pending_user_id', 'verification_method']) {
    if (!error || !isMissingColumnError(error, optionalColumn)) {
      continue;
    }

    delete activePayload[optionalColumn];
    ({ data, error } = await insertSession(activePayload));
  }

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  console.log(
    `[auth] Created WhatsApp ${purpose} verification ${data.id} for ${maskPhoneNumber(phoneNumber)}.`
  );

  return {
    otpSession: data,
    token,
    expiresAt,
    whatsappUrl,
  };
};

const createRegistrationVerification = (registrationData) =>
  createWhatsappVerification({
    phoneNumber: registrationData.phone_number,
    purpose: OTP_PURPOSE.REGISTER,
    registrationPayload: registrationData,
  });

const createLoginVerification = (phoneNumber, pendingUserId) =>
  createWhatsappVerification({
    phoneNumber,
    purpose: OTP_PURPOSE.LOGIN,
    pendingUserId,
  });

const getVerificationSessionById = async (verificationId) => {
  const { data, error } = await supabaseAdmin
    .from(OTP_SESSIONS_TABLE)
    .select('*')
    .eq('id', verificationId)
    .maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  return data;
};

const updateVerificationSession = async (verificationId, payload) => {
  const { data, error } = await supabaseAdmin
    .from(OTP_SESSIONS_TABLE)
    .update({
      ...payload,
      updated_at: nowIso(),
    })
    .eq('id', verificationId)
    .select()
    .single();

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  return data;
};

const expireVerificationSession = (otpSession) =>
  updateVerificationSession(otpSession.id, { status: 'expired' });

const resolveVerificationSessionStatus = async (verificationId) => {
  const otpSession = await getVerificationSessionById(verificationId);

  if (!otpSession) {
    throw new AppError('Verification session could not be found.', 404, 'verification_not_found');
  }

  if (otpSession.status === 'pending' && new Date(otpSession.expires_at).getTime() <= Date.now()) {
    return expireVerificationSession(otpSession);
  }

  return otpSession;
};

const phoneDigits = (phoneNumber) => normalizePhoneNumber(phoneNumber).replace(/\D/g, '');

const comparePhoneNumbers = ({ submittedPhoneNumber, senderPhoneNumber }) => {
  const submittedDigits = phoneDigits(submittedPhoneNumber);
  const senderDigits = phoneDigits(senderPhoneNumber);

  if (submittedDigits.length < 8 || senderDigits.length < 8) {
    return null;
  }

  return (
    submittedDigits === senderDigits ||
    submittedDigits.endsWith(senderDigits) ||
    senderDigits.endsWith(submittedDigits)
  );
};

const findSessionByToken = async (token) => {
  const { data, error } = await supabaseAdmin
    .from(OTP_SESSIONS_TABLE)
    .select('*')
    .eq('otp_code_hash', hashOtpCode(token))
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  return data;
};

const verifyIncomingWhatsappToken = async ({ token, senderPhoneNumber }) => {
  const normalizedToken = String(token ?? '').trim().toUpperCase();

  if (!/^CM-[A-Z0-9]{5}$/.test(normalizedToken)) {
    console.log('[WEBHOOK] DB lookup: not_found');
    return { verified: false, reason: 'invalid_token_format' };
  }

  const otpSession = await findSessionByToken(normalizedToken);

  if (!otpSession) {
    console.log('[WEBHOOK] DB lookup: not_found');
    return { verified: false, reason: 'token_not_found' };
  }

  if (!isWhatsappVerificationSession(otpSession)) {
    console.log('[WEBHOOK] DB lookup: not_found');
    return { verified: false, reason: 'invalid_verification_method' };
  }

  if (otpSession.status === 'verified') {
    console.log('[WEBHOOK] DB lookup: already_verified');
    return { verified: false, reason: 'already_verified' };
  }

  if (otpSession.status === 'cancelled') {
    console.log('[WEBHOOK] DB lookup: not_found');
    return { verified: false, reason: 'cancelled' };
  }

  // Check if expired
  const isExpired = new Date(otpSession.expires_at).getTime() <= Date.now();
  if (isExpired || otpSession.status === 'expired') {
    console.log('[WEBHOOK] DB lookup: expired');
    if (otpSession.status === 'pending') {
      try {
        await expireVerificationSession(otpSession);
      } catch (err) {
        console.error('[webhook] Failed to mark expired status in DB:', err.message);
      }
    }
    return { verified: false, reason: 'expired' };
  }

  console.log('[WEBHOOK] DB lookup: found');

  const normalizedSenderPhone = normalizePhoneNumber(senderPhoneNumber);
  const senderMatchesSubmitted = comparePhoneNumbers({
    submittedPhoneNumber: otpSession.phone_number,
    senderPhoneNumber: normalizedSenderPhone,
  });

  if (senderMatchesSubmitted !== true) {
    console.warn(
      `[webhook] WhatsApp sender ${maskPhoneNumber(normalizedSenderPhone)} did not match the pending verification phone number. proceeding anyway.`
    );
  }

  const metadata = {
    ...(otpSession.metadata ?? {}),
    whatsapp_sender_phone: normalizedSenderPhone || null,
    whatsapp_sender_matches_submitted: senderMatchesSubmitted,
    whatsapp_verified_via_webhook_at: nowIso(),
    submitted_phone: otpSession.phone_number,
    normalized_submitted_phone: normalizePhoneNumber(otpSession.phone_number),
    normalized_whatsapp_sender_phone: normalizedSenderPhone,
  };

  const updatePayload = {
    status: 'verified',
    verified_at: nowIso(),
    attempts: Math.max(otpSession.attempts ?? 0, 1),
    whatsapp_sender_phone: normalizedSenderPhone,
    normalized_whatsapp_sender_phone: normalizedSenderPhone,
    metadata,
    updated_at: nowIso(),
  };

  let data, error;
  try {
    const res = await supabaseAdmin
      .from(OTP_SESSIONS_TABLE)
      .update(updatePayload)
      .eq('id', otpSession.id)
      .eq('status', 'pending')
      .select()
      .maybeSingle();
    data = res.data;
    error = res.error;
  } catch (err) {
    error = err;
  }

  if (error && (isMissingColumnError(error, 'whatsapp_sender_phone') || isMissingColumnError(error, 'normalized_whatsapp_sender_phone'))) {
    const fallbackPayload = {
      status: 'verified',
      verified_at: nowIso(),
      attempts: Math.max(otpSession.attempts ?? 0, 1),
      metadata,
      updated_at: nowIso(),
    };

    if (!isMissingColumnError(error, 'whatsapp_sender_phone')) {
      fallbackPayload.whatsapp_sender_phone = normalizedSenderPhone;
    }

    const res = await supabaseAdmin
      .from(OTP_SESSIONS_TABLE)
      .update(fallbackPayload)
      .eq('id', otpSession.id)
      .eq('status', 'pending')
      .select()
      .maybeSingle();
    data = res.data;
    error = res.error;
  }

  if (error) {
    throw wrapDatabaseError(error, OTP_SESSIONS_TABLE);
  }

  if (!data) {
    console.log('[WEBHOOK] DB lookup: already_verified');
    return { verified: false, reason: 'already_processed' };
  }

  console.log(`[WEBHOOK] Verification updated: verificationId=${data.id}`);

  // Update existing user phone verification if user exists
  let userId = 'none';
  try {
    const { data: existingUser } = await supabaseAdmin
      .from('users')
      .select('id')
      .eq('phone_number', otpSession.phone_number)
      .maybeSingle();

    if (existingUser) {
      userId = existingUser.id;
      await supabaseAdmin
        .from('users')
        .update({
          phone_verified: true,
          phone_verified_at: nowIso(),
          updated_at: nowIso(),
        })
        .eq('id', userId);

      await supabaseAdmin.auth.admin.updateUserById(userId, {
        phone_confirm: true,
      });
    }
  } catch (err) {
    console.warn('[webhook] Failed to update user phone verification directly:', err.message);
  }

  console.log(
    `[webhook] Verified WhatsApp ${data.purpose} session ${data.id} from ${maskPhoneNumber(normalizedSenderPhone)}.`
  );

  return {
    verified: true,
    verificationId: data.id,
    otpSession: data,
    userId,
  };
};

module.exports = {
  WHATSAPP_INBOUND_METHOD,
  buildWhatsappUrl,
  createLoginVerification,
  createRegistrationVerification,
  extractVerificationToken,
  getWhatsappBusinessNumber,
  resolveVerificationSessionStatus,
  verifyIncomingWhatsappToken,
};
