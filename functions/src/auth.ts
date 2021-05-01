import { FirestoreStore } from "@google-cloud/connect-firestore";
import { Firestore } from "@google-cloud/firestore";
import * as crypto from "crypto";
import * as express from "express";
import * as expressSession from "express-session";
import * as admin from "firebase-admin";
import fetch from "node-fetch";
import { AuthorizationCode } from "simple-oauth2";
import { TWITCH_CLIENT_ID, TWITCH_OAUTH_CONFIG } from "./oauth";

const app = express();

app.use(
  expressSession({
    store: new FirestoreStore({
      dataset: new Firestore(),
      kind: "express-sessions",
    }),
    name: "__session",
    secret: "ishdcr78aw34rycn*&#FHCa8e7fh32c",
    resave: true,
    saveUninitialized: true,
    rolling: true,
    cookie: { maxAge: 60000, secure: "auto", httpOnly: true },
  })
);

declare module "express-session" {
  interface Session {
    state?: string;
  }
}

const HOST =
  process.env.NODE_ENV === "production"
    ? "https://chat.rtirl.com"
    : "http://localhost:5000";

async function createFirebaseAccount(userId: string, token: string) {
  // The UID we'll assign to the user.
  const uid = `twitch:${userId}`;

  // Save the access token to the Firebase Realtime Database.
  const databaseTask = admin
    .firestore()
    .collection("tokens")
    .doc(uid)
    .set({ token });

  // Create or update the user account.
  const userCreationTask = admin
    .auth()
    .getUser(uid)
    .catch((error) => {
      // If user does not exists we create it.
      if (error.code === "auth/user-not-found") {
        return admin.auth().createUser({ uid });
      }
      throw error;
    });

  // Wait for all async task to complete then generate and return a custom auth token.
  await Promise.all([userCreationTask, databaseTask]);
  // Create a Firebase custom auth token.
  return { token: await admin.auth().createCustomToken(uid), uid };
}

app.get("/auth/twitch", (req, res) => {
  const state = req.session.state || crypto.randomBytes(20).toString("hex");
  req.session.state = state.toString();
  const redirectUri = new AuthorizationCode(TWITCH_OAUTH_CONFIG).authorizeURL({
    redirect_uri: `${HOST}/auth/twitch/callback`,
    scope: ["user:read:email", "chat:read", "chat:edit"],
    state: state,
  });
  res.redirect(redirectUri);
});

app.get("/auth/twitch/callback", async (req, res) => {
  if (!req.session?.state) {
    res.status(500).send("state not set");
    return;
  } else if (req.session.state !== req.session.state) {
    res.status(403).send("incorrect state");
    return;
  }
  const results = await new AuthorizationCode(TWITCH_OAUTH_CONFIG).getToken({
    code: String(req.query.code),
    redirect_uri: `${HOST}/auth/twitch/callback`,
  });

  const accessToken = JSON.stringify(results.token);

  const users = await fetch("https://api.twitch.tv/helix/users", {
    headers: {
      Authorization: `Bearer ${results.token.access_token}`,
      "Client-Id": TWITCH_CLIENT_ID,
    },
  }).then((response) => response.json());

  const twitchUserId = users["data"][0]["id"];

  req.session.state = undefined;

  // Create a Firebase account and get the Custom Auth Token.
  const firebaseToken = await createFirebaseAccount(twitchUserId, accessToken);

  res.redirect(
    "com.rtirl.chat://auth/twitch?token=" +
      encodeURIComponent(firebaseToken.token)
  );
});

export { app };
