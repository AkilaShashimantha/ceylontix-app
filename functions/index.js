const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");

admin.initializeApp();

/**
 * Callable Cloud Function to grant a user the admin role.
 */
exports.addAdminRole = functions.https.onCall(async (data, context) => {
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can add other admins.",
    );
  }

  const email = data.email;
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "The function must be called with one argument 'email'.",
    );
  }

  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    return {
      message: `Success! ${email} has been made an admin.`,
    };
  } catch (error) {
    console.error("Error setting custom claim:", error);
    throw new functions.https.HttpsError(
        "internal",
        "Error setting admin role.",
    );
  }
});

/**
 * Callable Cloud Function to generate a secure hash for PayHere web checkout.
 */
exports.generatePayHereHash = functions.https.onCall(async (data, context) => {
  const merchantSecret = functions.config().payhere.secret;
  if (!merchantSecret) {
    console.error(
        "CRITICAL: PayHere secret is not configured in Firebase Functions.",
    );
    throw new functions.https.HttpsError(
        "internal",
        "Server configuration error. Please contact support.",
    );
  }

  const merchantId = data.merchant_id;
  const orderId = data.order_id;
  const amount = parseFloat(data.amount).toFixed(2);
  const currency = data.currency;

  const hashedSecret = crypto.createHash("md5")
      .update(merchantSecret).digest("hex").toUpperCase();
  const prehash = merchantId + orderId + amount + currency + hashedSecret;

  const hash = crypto.createHash("md5")
      .update(prehash).digest("hex").toUpperCase();

  return {hash: hash};
});
