const crypto = require('crypto');
const { onCall, onRequest, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const { defineSecret } = require('firebase-functions/params');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const OTP_COLLECTION = 'email_otp_challenges';
const MAIL_COLLECTION = 'mail';
const OTP_PURPOSE_LOGIN = 'login';
const OTP_PURPOSE_PASSWORD_RESET = 'password_reset';
const OTP_TTL_MINUTES = 5;
const RESEND_COOLDOWN_SECONDS = 30;
const MAX_ATTEMPTS = 5;
const otpPepper = defineSecret('OTP_PEPPER');

function generateCode() {
  return `${Math.floor(100000 + Math.random() * 900000)}`;
}

function generateSalt() {
  return crypto.randomBytes(16).toString('hex');
}

function hashCode(code, salt) {
  const pepper = otpPepper.value() || '';
  return crypto
    .createHash('sha256')
    .update(`${code}:${salt}:${pepper}`)
    .digest('hex');
}

exports.startEmailOtpLogin = onCall(
  { enforceAppCheck: false, secrets: [otpPepper] },
  async (request) => {
  const uid = request.auth?.uid;
  const email = (request.data?.email || '').toString().trim().toLowerCase();

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }
  if (!email) {
    throw new HttpsError('invalid-argument', 'Email is required.');
  }

  const now = admin.firestore.Timestamp.now();
  const cooldownCutoff = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - RESEND_COOLDOWN_SECONDS * 1000,
  );

  const userChallengesSnapshot = await db
    .collection(OTP_COLLECTION)
    .where('uid', '==', uid)
    .limit(50)
    .get();

  let recentActiveChallengeId = null;
  const activeChallengeDocs = [];

  const sortedDocs = [...userChallengesSnapshot.docs].sort((a, b) => {
    const aCreatedAt = a.data().createdAt?.toMillis?.() ?? 0;
    const bCreatedAt = b.data().createdAt?.toMillis?.() ?? 0;
    return bCreatedAt - aCreatedAt;
  });

  for (const doc of sortedDocs) {
    const data = doc.data();
    if (data.purpose !== OTP_PURPOSE_LOGIN) {
      continue;
    }

    const isUnused = data.used === false;
    const createdAtMs = data.createdAt?.toMillis?.() ?? 0;
    const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;

    if (isUnused) {
      activeChallengeDocs.push(doc);
    }

    if (
      isUnused &&
      createdAtMs >= cooldownCutoff.toMillis() &&
      expiresAtMs > Date.now()
    ) {
      recentActiveChallengeId = doc.id;
      break;
    }
  }

  if (recentActiveChallengeId) {
    return { challengeId: recentActiveChallengeId };
  }

  const batch = db.batch();
  for (const doc of activeChallengeDocs) {
    batch.update(doc.ref, { used: true, invalidatedAt: now });
  }

  const code = generateCode();
  const salt = generateSalt();
  const codeHash = hashCode(code, salt);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + OTP_TTL_MINUTES * 60 * 1000,
  );

  const challengeRef = db.collection(OTP_COLLECTION).doc();
  batch.set(challengeRef, {
    uid,
    email,
    purpose: OTP_PURPOSE_LOGIN,
    codeHash,
    salt,
    attempts: 0,
    used: false,
    createdAt: now,
    expiresAt,
  });

  const mailRef = db.collection(MAIL_COLLECTION).doc();
  batch.set(mailRef, {
    to: [email],
    message: {
      subject: 'Your E-Secret Tracker verification code',
      text: `Your verification code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`,
      html: `<p>Your verification code is <strong>${code}</strong>.</p><p>It expires in ${OTP_TTL_MINUTES} minutes.</p>`,
    },
    createdAt: now,
  });

  await batch.commit();
  return { challengeId: challengeRef.id };
});

exports.verifyEmailOtpLogin = onCall(
  { enforceAppCheck: false, secrets: [otpPepper] },
  async (request) => {
  const uid = request.auth?.uid;
  const challengeId = (request.data?.challengeId || '').toString().trim();
  const code = (request.data?.code || '').toString().trim();

  if (!uid) {
    throw new HttpsError('unauthenticated', 'Sign in first.');
  }
  if (!challengeId || !code) {
    throw new HttpsError('invalid-argument', 'Challenge ID and code are required.');
  }

  const challengeRef = db.collection(OTP_COLLECTION).doc(challengeId);
  const challengeSnap = await challengeRef.get();

  if (!challengeSnap.exists) {
    throw new HttpsError('not-found', 'Verification challenge not found.');
  }

  const challenge = challengeSnap.data();
  if (challenge.uid !== uid || challenge.purpose !== OTP_PURPOSE_LOGIN) {
    throw new HttpsError('permission-denied', 'This challenge does not belong to you.');
  }
  if (challenge.used) {
    throw new HttpsError('failed-precondition', 'Challenge already used.');
  }
  if (challenge.expiresAt.toMillis() < Date.now()) {
    await challengeRef.update({ used: true, expiredAt: admin.firestore.Timestamp.now() });
    throw new HttpsError('deadline-exceeded', 'Code expired. Request a new one.');
  }
  if ((challenge.attempts || 0) >= MAX_ATTEMPTS) {
    throw new HttpsError('resource-exhausted', 'Too many failed attempts.');
  }

  const submittedHash = hashCode(code, challenge.salt);
  if (submittedHash !== challenge.codeHash) {
    await challengeRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError('permission-denied', 'Invalid code.');
  }

  await challengeRef.update({
    used: true,
    verifiedAt: admin.firestore.Timestamp.now(),
  });

  return { verified: true };
});

async function startPasswordResetChallengeInternal({ email }) {
  const normalizedEmail = (email || '').toString().trim().toLowerCase();

  if (!normalizedEmail) {
    throw new HttpsError('invalid-argument', 'Email is required.');
  }

  const now = admin.firestore.Timestamp.now();
  const cooldownCutoff = admin.firestore.Timestamp.fromMillis(
    now.toMillis() - RESEND_COOLDOWN_SECONDS * 1000,
  );

  const existingChallengesSnapshot = await db
    .collection(OTP_COLLECTION)
    .where('email', '==', normalizedEmail)
    .where('purpose', '==', OTP_PURPOSE_PASSWORD_RESET)
    .limit(50)
    .get();

  let recentActiveChallengeId = null;
  const activeChallengeDocs = [];

  const sortedDocs = [...existingChallengesSnapshot.docs].sort((a, b) => {
    const aCreatedAt = a.data().createdAt?.toMillis?.() ?? 0;
    const bCreatedAt = b.data().createdAt?.toMillis?.() ?? 0;
    return bCreatedAt - aCreatedAt;
  });

  for (const doc of sortedDocs) {
    const data = doc.data();
    const isUnused = data.used === false;
    const createdAtMs = data.createdAt?.toMillis?.() ?? 0;
    const expiresAtMs = data.expiresAt?.toMillis?.() ?? 0;

    if (isUnused) {
      activeChallengeDocs.push(doc);
    }

    if (
      isUnused &&
      createdAtMs >= cooldownCutoff.toMillis() &&
      expiresAtMs > Date.now()
    ) {
      recentActiveChallengeId = doc.id;
      break;
    }
  }

  if (recentActiveChallengeId) {
    return { challengeId: recentActiveChallengeId };
  }

  const batch = db.batch();
  for (const doc of activeChallengeDocs) {
    batch.update(doc.ref, { used: true, invalidatedAt: now });
  }

  const code = generateCode();
  const salt = generateSalt();
  const codeHash = hashCode(code, salt);
  const expiresAt = admin.firestore.Timestamp.fromMillis(
    now.toMillis() + OTP_TTL_MINUTES * 60 * 1000,
  );

  const challengeRef = db.collection(OTP_COLLECTION).doc();
  batch.set(challengeRef, {
    uid: null,
    email: normalizedEmail,
    purpose: OTP_PURPOSE_PASSWORD_RESET,
    codeHash,
    salt,
    attempts: 0,
    used: false,
    createdAt: now,
    expiresAt,
  });

  const mailRef = db.collection(MAIL_COLLECTION).doc();
  batch.set(mailRef, {
    to: [normalizedEmail],
    message: {
      subject: 'Your E-Secret Tracker password reset code',
      text: `Your password reset code is ${code}. It expires in ${OTP_TTL_MINUTES} minutes.`,
      html: `<p>Your password reset code is <strong>${code}</strong>.</p><p>It expires in ${OTP_TTL_MINUTES} minutes.</p>`,
    },
    createdAt: now,
  });

  await batch.commit();
  return { challengeId: challengeRef.id };
}

async function verifyPasswordResetChallengeInternal({ challengeId, code, newPassword }) {
  const normalizedChallengeId = (challengeId || '').toString().trim();
  const normalizedCode = (code || '').toString().trim();
  const normalizedNewPassword = (newPassword || '').toString();

  if (!normalizedChallengeId || !normalizedCode || !normalizedNewPassword) {
    throw new HttpsError('invalid-argument', 'Challenge ID, code, and new password are required.');
  }
  if (normalizedNewPassword.length < 6) {
    throw new HttpsError('invalid-argument', 'Password must be at least 6 characters long.');
  }

  const challengeRef = db.collection(OTP_COLLECTION).doc(normalizedChallengeId);
  const challengeSnap = await challengeRef.get();

  if (!challengeSnap.exists) {
    throw new HttpsError('not-found', 'Verification challenge not found.');
  }

  const challenge = challengeSnap.data();
  if (challenge.purpose !== OTP_PURPOSE_PASSWORD_RESET) {
    throw new HttpsError('permission-denied', 'Invalid challenge purpose.');
  }
  if (challenge.used) {
    throw new HttpsError('failed-precondition', 'Challenge already used.');
  }
  if (challenge.expiresAt.toMillis() < Date.now()) {
    await challengeRef.update({ used: true, expiredAt: admin.firestore.Timestamp.now() });
    throw new HttpsError('deadline-exceeded', 'Code expired. Request a new one.');
  }
  if ((challenge.attempts || 0) >= MAX_ATTEMPTS) {
    throw new HttpsError('resource-exhausted', 'Too many failed attempts.');
  }

  const submittedHash = hashCode(normalizedCode, challenge.salt);
  if (submittedHash !== challenge.codeHash) {
    await challengeRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError('permission-denied', 'Invalid code.');
  }

  const now = admin.firestore.Timestamp.now();
  let targetUid = challenge.uid || null;

  if (!targetUid && challenge.email) {
    try {
      const userRecord = await admin.auth().getUserByEmail(challenge.email);
      targetUid = userRecord.uid;
    } catch (error) {
      if (error?.code !== 'auth/user-not-found') {
        logger.error('Failed to resolve user during password reset verification.', {
          email: challenge.email,
          code: error?.code,
        });
        throw new HttpsError('internal', 'Unable to complete password reset right now.');
      }
    }
  }

  if (targetUid) {
    await admin.auth().updateUser(targetUid, { password: normalizedNewPassword });
  } else {
    throw new HttpsError('not-found', 'No account was found for this reset request.');
  }

  await challengeRef.update({
    used: true,
    verifiedAt: now,
    passwordResetAt: now,
  });

  return { verified: true };
}

function httpStatusFromHttpsErrorCode(code) {
  switch (code) {
    case 'invalid-argument':
      return 400;
    case 'unauthenticated':
      return 401;
    case 'permission-denied':
      return 403;
    case 'not-found':
      return 404;
    case 'failed-precondition':
      return 412;
    case 'resource-exhausted':
      return 429;
    case 'deadline-exceeded':
      return 408;
    case 'unavailable':
      return 503;
    default:
      return 500;
  }
}

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}

exports.startEmailOtpPasswordReset = onCall(
  { enforceAppCheck: false, secrets: [otpPepper] },
  async (request) => {
    return startPasswordResetChallengeInternal({ email: request.data?.email });
  },
);

exports.verifyEmailOtpPasswordReset = onCall(
  { enforceAppCheck: false, secrets: [otpPepper] },
  async (request) => {
    return verifyPasswordResetChallengeInternal({
      challengeId: request.data?.challengeId,
      code: request.data?.code,
      newPassword: request.data?.newPassword,
    });
  },
);

exports.startEmailOtpPasswordResetHttp = onRequest({ secrets: [otpPepper] }, async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  try {
    const result = await startPasswordResetChallengeInternal({ email: req.body?.email });
    return res.status(200).json(result);
  } catch (error) {
    if (error instanceof HttpsError) {
      return res.status(httpStatusFromHttpsErrorCode(error.code)).json({
        error: error.message,
        code: error.code,
      });
    }

    logger.error('Unexpected error in startEmailOtpPasswordResetHttp.', error);
    return res.status(500).json({ error: 'Unable to send code right now.' });
  }
});

exports.verifyEmailOtpPasswordResetHttp = onRequest({ secrets: [otpPepper] }, async (req, res) => {
  setCors(res);
  if (req.method === 'OPTIONS') {
    return res.status(204).send('');
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed.' });
  }

  try {
    const result = await verifyPasswordResetChallengeInternal({
      challengeId: req.body?.challengeId,
      code: req.body?.code,
      newPassword: req.body?.newPassword,
    });
    return res.status(200).json(result);
  } catch (error) {
    if (error instanceof HttpsError) {
      return res.status(httpStatusFromHttpsErrorCode(error.code)).json({
        error: error.message,
        code: error.code,
      });
    }

    logger.error('Unexpected error in verifyEmailOtpPasswordResetHttp.', error);
    return res.status(500).json({ error: 'Unable to verify code right now.' });
  }
});