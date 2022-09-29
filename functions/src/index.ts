import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import fetch from "cross-fetch";
import { app as authApp } from "./auth";
import { getUserEmotes, getEmotes } from "./emotes";
import { eventsub } from "./eventsub";
import { getAppAccessToken, TWITCH_CLIENT_ID } from "./oauth";
import { search } from "./search";
import { cleanup, subscribe, unsubscribe } from "./subscriptions";
import { synthesize, getVoices } from "./tts";
import { getTwitchLogin, getChannelId } from "./twitch";
import { updateChatStatus } from "./chat-status";
import {
  setRealTimeCashAddress,
  alchemyWebhook,
  ethAlchemyWebhook,
} from "./alchemy_webhook";

async function write(
  channelId: string,
  targetChannel: string,
  message: string
) {
  const ref = await admin.firestore().collection("actions").add({
    channelId,
    targetChannel,
    message,
    sentAt: null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  // wait for the message to be sent.
  const error = await new Promise<string | null>((resolve) =>
    ref.onSnapshot((snapshot) => {
      if (snapshot.get("isComplete")) {
        resolve(snapshot.get("error") || null);
      }
    })
  );
  return error;
}

export const send = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  const message = data?.message;
  if (!provider || !channelId || !message) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId, message"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        message
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const ban = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  const username = data?.username;
  const reason = data?.reason;
  if (!provider || !channelId || !username || !reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId, username, reason"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        `/ban ${username} ${reason}`
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const unban = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  const username = data?.username;
  if (!provider || !channelId || !username) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId, username"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        `/unban ${username}`
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const timeout = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  const username = data?.username;
  const length = data?.length;
  const reason = data?.reason;
  if (!provider || !channelId || !username || !length || !reason) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId, username, length, reason"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        `/timeout ${username} ${length} ${reason}`
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const deleteMessage = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  const messageId = data?.messageId;
  if (!provider || !channelId || !messageId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId, messageId"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        `/delete ${messageId.substring("twitch:".length)}`
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const clear = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("permission-denied", "missing auth");
  }
  const provider = data?.provider;
  const channelId = data?.channelId;
  if (!provider || !channelId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId"
    );
  }

  switch (provider) {
    case "twitch":
      const targetChannel = await getTwitchLogin(channelId);
      if (!targetChannel) {
        return;
      }
      const response = await write(
        await getChannelId(context.auth.uid, "twitch"),
        targetChannel,
        `/clear`
      );
      return response;
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const getStatistics = functions.https.onCall(async (data, context) => {
  const provider = data?.provider;
  const channelId = data?.channelId;
  if (!provider || !channelId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId"
    );
  }

  switch (provider) {
    case "twitch":
      const token = await getAppAccessToken(provider);
      if (!token) {
        throw new functions.https.HttpsError("internal", "auth error");
      }
      const headers = {
        "Client-Id": TWITCH_CLIENT_ID,
        Authorization: `Bearer ${token.token["access_token"]}`,
      };
      const viewerResponse = await fetch(
        `https://api.twitch.tv/helix/streams?user_id=${channelId}&first=1`,
        { headers }
      );
      const viewerJson = (await viewerResponse.json()) as any;
      const followerResponse = await fetch(
        `https://api.twitch.tv/helix/users/follows?to_id=${channelId}&first=1`,
        { headers }
      );
      const followerJson = (await followerResponse.json()) as any;
      const stream = viewerJson["data"][0];
      const languageResponse = await fetch(
        `https://api.twitch.tv/helix/channels?broadcaster_id=${channelId}`,
        { headers }
      );
      const languageJson = (await languageResponse.json()) as any;
      if (!stream) {
        return {
          isOnline: false,
          viewers: 0,
          followers: followerJson["total"],
          language: languageJson["data"][0]["broadcaster_language"],
        };
      }
      return {
        isOnline: true,
        viewers: stream["viewer_count"],
        followers: followerJson["total"],
        language: languageJson["data"][0]["broadcaster_language"],
      };
  }

  throw new functions.https.HttpsError("invalid-argument", "invalid provider");
});

export const getProfilePicture = functions.https.onRequest(async (req, res) => {
  const provider = req.query?.provider as string | null;
  const channelId = req.query?.channelId as string | null;
  if (!provider || !channelId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId"
    );
  }

  switch (provider) {
    case "twitch":
      const token = await getAppAccessToken(provider);
      if (!token) {
        throw new functions.https.HttpsError("internal", "auth error");
      }
      const headers = {
        Authorization: `Bearer ${token.token["access_token"]}`,
        "Client-Id": TWITCH_CLIENT_ID,
      };
      try {
        const response = await fetch(
          `https://api.twitch.tv/helix/users?id=${channelId}`,
          { headers: headers }
        );
        const json = (await response.json()) as any;
        const imageUrl =
          json["data"]?.[0]?.["profile_image_url"] ??
          "https://static-cdn.jtvnw.net/user-default-pictures-uv/ebb84563-db81-4b9c-8940-64ed33ccfc7b-profile_image-300x300.png";
        const image = await fetch(imageUrl);
        res.setHeader("Content-Type", "image/png");
        res.setHeader("Cache-Control", "public, max-age=86400, s-maxage=86400");
        res.status(200).send(Buffer.from(await image.arrayBuffer()));
      } catch (err) {
        console.error(err);
        throw new functions.https.HttpsError("not-found", "image not found");
      }
    default:
      throw new functions.https.HttpsError(
        "invalid-argument",
        "invalid provider"
      );
  }
});

export const embedRedirect = functions.https.onRequest(async (req, res) => {
  const provider = req.query?.provider as string | null;
  const channelId = req.query?.channelId as string | null;
  if (!provider || !channelId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "missing provider, channelId"
    );
  }
  switch (provider) {
    case "twitch":
      const login = await getTwitchLogin(channelId);
      if (!login) {
        throw new functions.https.HttpsError("not-found", "channel not found");
      }
      res.redirect(
        `https://player.twitch.tv/?channel=${login}&controls=false&parent=chat.rtirl.com&muted=true`
      );
      break;
    default:
      throw new functions.https.HttpsError(
        "invalid-argument",
        "invalid provider"
      );
  }
});

export {
  subscribe,
  unsubscribe,
  eventsub,
  search,
  getUserEmotes,
  getEmotes,
  cleanup,
  synthesize,
  getVoices,
  updateChatStatus,
  setRealTimeCashAddress,
  alchemyWebhook,
  ethAlchemyWebhook,
};
export const auth = functions.https.onRequest(authApp);
