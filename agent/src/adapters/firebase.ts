import * as admin from "firebase-admin";
import { AuthorizationCode, ModuleOptions } from "simple-oauth2";
import { ClearMessageMessage, PrivateMessage } from "twitch-js";

const TWITCH_CLIENT_ID = process.env["TWITCH_CLIENT_ID"];
const TWITCH_CLIENT_SECRET = process.env["TWITCH_CLIENT_SECRET"];
const TWITCH_BOT_USER_ID = process.env["TWITCH_BOT_USER_ID"];

export const TWITCH_OAUTH_CONFIG = {
  client: {
    id: TWITCH_CLIENT_ID,
    secret: TWITCH_CLIENT_SECRET,
  },
  auth: {
    tokenHost: "https://id.twitch.tv",
    tokenPath: "/oauth2/token",
    authorizePath: "/oauth2/authorize",
  },
  options: {
    bodyFormat: "json",
    authorizationMethod: "body",
  },
} as ModuleOptions<"client_id">;

export function parseTimestamp(
  timestamp: string | undefined
): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(Number(timestamp));
}

function getBotUserId(provider: string) {
  switch (provider) {
    case "twitch":
      return TWITCH_BOT_USER_ID;
  }
}

/**
 * Computes the difference between two sets.
 */
function diff<T>(a: Set<T>, b: Set<T>) {
  return new Set<T>(Array.from(a).filter((x) => !b.has(x)));
}

export class FirebaseAdapter {
  constructor(
    private firebase: admin.database.Database,
    private firestore: admin.firestore.Firestore,
    private provider: string
  ) {}

  private getMessage(key: string) {
    return this.firestore.collection("messages").doc(key);
  }

  async getCredentials(forceRefresh = false) {
    const userId = getBotUserId(this.provider);
    if (!userId) {
      throw new Error("invalid provider");
    }

    const username = (
      await this.firestore.collection("profiles").doc(userId).get()
    ).get(this.provider)["login"] as string;

    // fetch the token from the database.
    const ref = this.firestore.collection("tokens").doc(userId);
    const encoded = (await ref.get()).get(this.provider);
    if (!encoded) {
      throw new Error("token not found");
    }
    const client = new AuthorizationCode(TWITCH_OAUTH_CONFIG);
    let accessToken = client.createToken(JSON.parse(encoded));
    while (accessToken.expired(3600) || forceRefresh) {
      try {
        forceRefresh = false;
        accessToken = await accessToken.refresh();
      } catch (err) {
        if (err.data?.payload?.message === "Invalid refresh token") {
          throw new Error("invalid refresh token");
        }
        throw err;
      }
    }
    await ref.update({ [this.provider]: JSON.stringify(accessToken.token) });
    return {
      token: accessToken.token,
      username,
    };
  }

  async addMessage(
    channelId: string,
    messageId: string,
    message: string,
    timestamp: Date,
    tags: any
  ) {
    await this.getMessage(`twitch:${messageId}`).set({
      channelId: `${this.provider}:${channelId}`,
      type: "message",
      timestamp: admin.firestore.Timestamp.fromDate(timestamp),
      tags,
      message,
    });
  }

  async deleteMessage(messageId: string, timestamp: Date, tags: any) {
    const original = await this.getMessage(`twitch:${messageId}`).get();

    if (!original.exists) {
      return;
    }

    await this.getMessage(`twitch:x-${messageId}`).set({
      channelId: original.get("channelId"),
      type: "messagedeleted",
      timestamp: admin.firestore.Timestamp.fromDate(timestamp),
      tags,
      messageId,
    });
  }

  onAssignment(
    provider: string,
    agentId: string,
    join: (channel: string) => Promise<void>,
    leave: (channel: string) => Promise<void>
  ): () => void {
    const channels = new Set<string>();
    const ref = this.firebase.ref("agents").child(provider);

    const claimListener = async (snapshot: admin.database.DataSnapshot) => {
      const channel = Object.keys(snapshot.val()).pop();
      if (!channel) {
        return;
      }
      ref.child(channel).transaction((data) => {
        if (data !== "") {
          return;
        }
        return agentId;
      });
    };

    const assignListener = async (snapshot: admin.database.DataSnapshot) => {
      const requestedChannels = new Set(Object.keys(snapshot.val() || {}));

      // TODO: handle join failure in a way that doesn't cause infinite loops.
      const add = diff(channels, requestedChannels);
      const remove = diff(channels, requestedChannels);
      for (const channel of add) {
        await join(channel);
        channels.add(channel);
      }
      for (const channel of remove) {
        await leave(channel);
        channels.delete(channel);
      }
    };

    const claimRef = ref.orderByValue().limitToFirst(1).equalTo("");
    const assignRef = ref.orderByValue().equalTo("");

    assignRef.on("value", assignListener);
    claimRef.on("value", claimListener);

    return () => {
      claimRef.off("value", claimListener);
      assignRef.off("value", assignListener);
    };
  }
}
