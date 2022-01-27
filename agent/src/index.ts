import { SecretManagerServiceClient } from "@google-cloud/secret-manager";
import * as admin from "firebase-admin";
import { v4 as uuidv4 } from "uuid";
import { runTwitchAgent } from "./agents/twitch";

const PROJECT_ID = process.env["PROJECT_ID"] || "rtchat-47692";

async function main() {
  if (!process.env["GOOGLE_APPLICATION_CREDENTIALS"]) {
    const client = new SecretManagerServiceClient();
    // credentials are not set, initialize the app from secret manager.
    // TODO: why don't gcp default credentials work?
    const [version] = await client.accessSecretVersion({
      name: "projects/rtchat-47692/secrets/firebase-service-account/versions/latest",
    });
    const secret = version.payload?.data?.toString();
    if (!secret) {
      throw new Error("unable to retrieve credentials from secret manager");
    }
    admin.initializeApp({
      credential: admin.credential.cert(JSON.parse(secret)),
      databaseURL: `https://${PROJECT_ID}-default-rtdb.firebaseio.com`,
    });
  } else {
    admin.initializeApp({
      databaseURL: `https://${PROJECT_ID}-default-rtdb.firebaseio.com`,
    });
  }

  const AGENT_ID = uuidv4();

  console.log("running agent", AGENT_ID);

  runTwitchAgent(AGENT_ID).then((close) => {
    for (const signal of ["SIGINT", "SIGTERM", "uncaughtException"]) {
      process.on(signal, async (err) => {
        console.error("received", signal, "with error", err);
        await close();
        process.exit(0);
      });
    }
  });
}

main().catch(console.error);
