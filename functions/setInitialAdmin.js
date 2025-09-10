const admin = require("firebase-admin");

// IMPORTANT: Path to your downloaded service account key
const serviceAccount = require("./service-account-key.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// The email of the user you want to make an admin.
// Provide via CLI: `node setInitialAdmin.js user@example.com`
// or env var ADMIN_EMAIL. Falls back to hard-coded default if neither provided.
const argEmail = (process.argv[2] || "").trim();
const envEmail = (process.env.ADMIN_EMAIL || "").trim();
const defaultEmail = "akilashashimantha84@gmail.com";
const adminEmail = argEmail || envEmail || defaultEmail;

/**
 * Sets the admin custom claim for the given email.
 * @return {Promise<void>} A promise that resolves when complete.
 */
async function setAdmin() {
  try {
    if (!adminEmail) {
      throw new Error(
          "No admin email provided. Pass via CLI arg or ADMIN_EMAIL env var.",
      );
    }
    const user = await admin.auth().getUserByEmail(adminEmail);
    await admin.auth().setCustomUserClaims(user.uid, {admin: true});
    console.log(`Successfully made ${adminEmail} an admin.`);
    process.exit(0);
  } catch (error) {
    console.error("Error setting admin:", error);
    process.exit(1);
  }
}

setAdmin();
