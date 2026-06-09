const { authConfig, buildDebugOtpHelperMessage } = require('../config/authConfig');
const { OTP_PURPOSE, normalizeOtpPurpose } = require('../constants/otpPurpose');
const { AppError } = require('../utils/appError');
const otpService = require('./otpService');
const { createAppSession } = require('./sessionService');
const userService = require('./userService');
const whatsappVerificationService = require('./whatsappVerificationService');

const buildOtpStartResponse = (otpSession, message) => ({
  success: true,
  message,
  otp_session_id: otpSession.id,
  phone_number: otpSession.phone_number,
  expires_at: otpSession.expires_at,
  next_step: 'verify_otp',
  otp_length: otpSession.metadata?.otp_length ?? authConfig.primaryOtpLength,
  auto_verify_ready: Boolean(otpSession.metadata?.auto_verify_ready),
  debug: otpSession.debug,
});

const startLoginOtp = async ({ phone_number }) => {
  const startTime = Date.now();
  const existingUser = await userService.getUserByPhoneNumber(phone_number);

  if (!existingUser) {
    throw new AppError('No account found for this phone number. Please register first.', 404, 'user_not_found');
  }

  const verification = await whatsappVerificationService.createLoginVerification(
    phone_number,
    existingUser.id
  );
  
  const duration = Date.now() - startTime;
  console.log(`[auth] startLoginOtp for ${phone_number} completed in ${duration}ms`);

  return {
    ...buildWhatsappVerificationStartResponse(verification),
    message: 'Continue with WhatsApp to verify your login.',
  };
};

const startRegistrationOtp = async (registrationData) => {
  const otpSession = await otpService.createOtpSession({
    phoneNumber: registrationData.phone_number,
    purpose: OTP_PURPOSE.REGISTER,
    registrationPayload: registrationData,
  });

  return buildOtpStartResponse(
    otpSession,
    'Registration details accepted. Continue to OTP verification.'
  );
};

const buildWhatsappVerificationStartResponse = ({
  otpSession,
  token,
  expiresAt,
  whatsappUrl,
}) => ({
  success: true,
  message: 'Registration details accepted. Continue with WhatsApp verification.',
  verificationId: otpSession.id,
  token,
  expiresAt,
  whatsappUrl,
  next_step: 'verify_whatsapp',
  // Compatibility alias for older clients that still name this record an OTP session.
  otp_session_id: otpSession.id,
  expires_at: expiresAt,
});

const startRegistrationWhatsappVerification = async (registrationData) => {
  const startTime = Date.now();
  const verification = await whatsappVerificationService.createRegistrationVerification(
    registrationData
  );

  const duration = Date.now() - startTime;
  console.log(`[REGISTER_START] completed in ${duration}ms`);

  return buildWhatsappVerificationStartResponse(verification);
};

const buildAuthenticatedPayload = (user, emergencyContact, message) => {
  const enrichedUser = emergencyContact
    ? {
        ...user,
        emergency_contact: emergencyContact,
      }
    : user;

  const helperMessage = buildDebugOtpHelperMessage();

  return {
    success: true,
    message,
    session: createAppSession(enrichedUser),
    user: enrichedUser,
    redirect: '/dashboard',
    debug: helperMessage
      ? {
          mode: 'debug',
          helper_message: helperMessage,
        }
      : null,
  };
};

const finalizeRegistration = async (otpSession) => {
  const registrationPayload = otpSession.registration_payload;

  if (!registrationPayload) {
    throw new AppError('Registration session is missing payload data.', 500, 'registration_payload_missing');
  }

  const existingUser = await userService.getUserByPhoneNumber(otpSession.phone_number);
  const userId =
    existingUser?.id ||
    (
      await userService.ensureAuthUserForPhoneNumber({
        phoneNumber: otpSession.phone_number,
        fullName: registrationPayload.full_name,
      })
    ).id;

  let user = await userService.saveUserProfile({
    id: userId,
    full_name: registrationPayload.full_name,
    phone_number: otpSession.phone_number,
    quarter: registrationPayload.quarter,
    location_permission: registrationPayload.location_permission,
    latitude: registrationPayload.latitude ?? null,
    longitude: registrationPayload.longitude ?? null,
  });
  user = await userService.markUserPhoneVerified(user);

  const emergencyContact = await userService.saveEmergencyContact({
    user_id: user.id,
    contact_name: registrationPayload.emergency_contact.contact_name,
    phone_number: registrationPayload.emergency_contact.phone_number,
    relationship: registrationPayload.emergency_contact.relationship,
  });

  return buildAuthenticatedPayload(
    user,
    emergencyContact,
    'Phone verified. Registration completed successfully.'
  );
};

const finalizeLogin = async (otpSession) => {
  let user = await userService.getUserByPhoneNumber(otpSession.phone_number);

  if (!user) {
    throw new AppError('No registered profile exists for this phone number.', 404, 'user_not_found');
  }

  user = await userService.markUserPhoneVerified(user);

  const emergencyContact = await userService.getPrimaryEmergencyContact(user.id);

  return buildAuthenticatedPayload(user, emergencyContact, 'Phone verified successfully.');
};

const getVerificationStatus = async ({ verificationId }) => {
  const otpSession = await whatsappVerificationService.resolveVerificationSessionStatus(
    verificationId
  );
  const status = otpSession.status;

  if (status === 'pending') {
    return {
      success: true,
      verificationId: otpSession.id,
      status: 'pending',
      verified: false,
      expiresAt: otpSession.expires_at,
    };
  }

  if (status === 'expired') {
    return {
      success: true,
      verificationId: otpSession.id,
      status: 'expired',
      verified: false,
      expiresAt: otpSession.expires_at,
      message: 'Your verification link has expired. Please request a new one.',
    };
  }

  if (status !== 'verified') {
    return {
      success: true,
      verificationId: otpSession.id,
      status,
      verified: false,
      expiresAt: otpSession.expires_at,
    };
  }

  const otpPurpose = normalizeOtpPurpose(otpSession.purpose);
  let response;

  if (otpPurpose === OTP_PURPOSE.REGISTER) {
    response = await finalizeRegistration(otpSession);
  } else if (otpPurpose === OTP_PURPOSE.LOGIN) {
    response = await finalizeLogin(otpSession);
  } else {
    return {
      success: true,
      verificationId: otpSession.id,
      status: 'verified',
      verified: true,
      expiresAt: otpSession.expires_at,
    };
  }

  return {
    success: true,
    verificationId: otpSession.id,
    status: 'verified',
    verified: true,
    expiresAt: otpSession.expires_at,
    user: response.user,
    session: response.session,
    authToken: response.session?.access_token,
    message: response.message || 'WhatsApp verification complete.',
  };
};

const verifyOtp = async ({ phone_number, otp_code, otp_session_id }) => {
  const otpSession = await otpService.verifyOtpSession({
    phoneNumber: phone_number,
    otpCode: otp_code,
    otpSessionId: otp_session_id,
  });
  const otpPurpose = normalizeOtpPurpose(otpSession.purpose);

  try {
    if (otpPurpose === OTP_PURPOSE.REGISTER) {
      return await finalizeRegistration(otpSession);
    }

    if (otpPurpose === OTP_PURPOSE.LOGIN) {
      return await finalizeLogin(otpSession);
    }

    throw new AppError(
      `Unsupported OTP purpose: ${otpSession.purpose}`,
      500,
      'unsupported_otp_purpose'
    );
  } catch (errorToThrow) {
    try {
      await otpService.rollbackVerifiedOtpSession(otpSession);
    } catch (rollbackError) {
      console.error('OTP session rollback failed after post-verification error:', rollbackError);
    }

    throw errorToThrow;
  }
};

const resendOtp = async ({ phone_number, otp_session_id }) => {
  const otpSession = await otpService.resendOtpSession({
    phoneNumber: phone_number,
    otpSessionId: otp_session_id,
  });

  return buildOtpStartResponse(otpSession, 'OTP resent successfully');
};

module.exports = {
  getVerificationStatus,
  resendOtp,
  startLoginOtp,
  startRegistrationOtp,
  startRegistrationWhatsappVerification,
  verifyOtp,
};
