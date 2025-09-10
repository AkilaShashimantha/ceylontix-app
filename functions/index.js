const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Callable Cloud Function to grant a user the admin role.
 * Only an existing admin can call this function.
 */
exports.addAdminRole = functions.https.onCall(async (data, context) => {
  // Ensure the caller is authenticated and is an admin
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "The function must be called while authenticated.",
    );
  }
  const isAdmin = context.auth.token && context.auth.token.admin === true;
  if (!isAdmin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can add other admins.",
    );
  }

  // Validate input
  const email = (
    data && typeof data.email === "string" ? data.email : ""
  ).trim();
  if (!email) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Provide 'email' (non-empty string).",
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
