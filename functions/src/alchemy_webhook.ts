import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import fetch from "node-fetch";

type Log = {
  removed: boolean;
  address: string;
  data: string;
  topics: string[];
};

type RawContract = {
  rawvalue?: string;
  address?: string;
  decimal?: number;
};

type Activity = {
  category: string;
  fromAddress: string;
  toAddress: string;
  blockNum: string;
  value?: number;
  erc721TokenId?: string;
  asset?: string;
  hash: string;
  typeTraceAddress: string;
  rawContract?: RawContract;
  log?: Log;
};

type AddressEvent = {
  network: string;
  activity: Activity[];
};

type AddressNotification = {
  webhookId: string;
  id: string;
  createdAt: string;
  type: string;
  event: AddressEvent;
};

export const alchemyWebhook = functions.https.onRequest(async (req, res) => {
  const body = req.body;
  const notification: AddressNotification = body as AddressNotification;
  for (const activity of notification.event.activity) {
    // look for userId that associated with this address
    await admin
      .firestore()
      .collection("realtimecash")
      .where("address", "==", activity.toAddress)
      .get()
      .then(async (snapshot) => {
        // get channelId for each userId
        const profile = await admin
          .firestore()
          .collection("profiles")
          .where("userId", "==", snapshot.docs[0].id)
          .get();
        
        const channelId = profile.docs[0].data().id;
        const login = profile.docs[0].data().login;
        const displayName = profile.docs[0].data().displayName;

        // storing donation respoonses in realtimecash collection
        await admin.firestore().collection("messages").add({
          channelId: channelId,
          broadcaster_user_id: channelId,
          broadcaster_user_login: login,
          broadcaster_user_name: displayName,
          userId: snapshot.docs[0].id,
          webhookId: notification.webhookId,
          id: notification.id,
          createdAt: notification.createdAt,
          type: "realtimecash.donation",
          notificationType: notification.type,
          activity: activity,
        });
      })
  }
  res.status(200).send("OK");
});

type webhookIdResponse = {
  id: string;
  appId: string;
  network: string;
  webhookType: string;
  webHookUrl: string;
  isActive: boolean;
  timeCreated: string;
  addresses: string[];
};

export const setRealTimeCashAddress = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("permission-denied", "missing auth");
    }

    const userId = context.auth.uid;
    const address = data?.address;
    if (!address) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "missing userId, address params"
      );
    }

    // https://docs.alchemy.com/reference/create-webhook
    // create webhook for user with userId
    const options = {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-Alchemy-Token": "this-is-a-token", // TODO: get token from alchemy
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        network: "ETH_MAINNET",
        webhook_type: "ADDRESS_ACTIVITY",
        webhook_url: "localhost/{userId}", // TODO: replace with real webhook url
      }),
    };

    fetch("https://dashboard.alchemyapi.io/api/create-webhook", options)
      .then((response) => response.json())
      .then(async (response) => {
        const res = response as webhookIdResponse;
        const webhookId = res.id;
        await admin
          .firestore()
          .collection("realtimecash")
          .doc(userId)
          .set({
            address,
            webhookId,
          })
          .catch((error) => {
            // fail to write to firestore
            throw new functions.https.HttpsError(error, error.message);
          });
      })
      .catch((err) => {
        // fail to create webhook from alchemy
        throw new functions.https.HttpsError(err, err.message);
      });

    return;
  }
);
