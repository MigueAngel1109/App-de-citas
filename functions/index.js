const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Función programada (cron job) que se ejecuta periódicamente (cada 15 minutos).
 * Busca reservas confirmadas o activas cuyo horario de cita esté exactamente
 * a 24 horas (ventana de 23.5h a 24.5h) y envía una notificación push
 * con alerta temática a los usuarios involucrados (anfitrión y citas confirmadas).
 */
exports.checkReservation24hAlerts = functions.pubsub
  .schedule("every 15 minutes")
  .timeZone("America/Bogota")
  .onRun(async (context) => {
    const now = new Date();
    // Ventana de 24 horas antes: entre 23 horas y 45 minutos y 24 horas y 15 minutos
    const windowStart = new Date(now.getTime() + (23 * 60 + 45) * 60 * 1000);
    const windowEnd = new Date(now.getTime() + (24 * 60 + 15) * 60 * 1000);

    const db = admin.firestore();

    try {
      const snapshot = await db
        .collection("reservations")
        .where("status", "==", "active")
        .where("dateTime", ">=", admin.firestore.Timestamp.fromDate(windowStart))
        .where("dateTime", "<=", admin.firestore.Timestamp.fromDate(windowEnd))
        .get();

      if (snapshot.empty) {
        console.log("No reservations found for 24h notification alert in this window.");
        return null;
      }

      console.log(`Found ${snapshot.size} reservations approaching 24h window.`);

      for (const doc of snapshot.docs) {
        const data = doc.data();
        const resId = doc.id;

        // Evitar duplicar la notificación push si ya fue enviada
        if (data.alert24hSent) {
          continue;
        }

        const hostUserId = data.userId;
        const placeName = data.placeName || "tu cita";

        // Obtener usuario(s) a notificar (anfitrión y participantes con solicitud aceptada)
        const targetUserIds = new Set();
        if (hostUserId) targetUserIds.add(hostUserId);

        // Buscar matches o solicitudes aceptadas para esta reserva
        const requestsSnap = await db
          .collection("reservation_requests")
          .where("reservationId", "==", resId)
          .where("status", "==", "accepted")
          .get();

        requestsSnap.forEach((rDoc) => {
          const rData = rDoc.data();
          if (rData.requesterId) targetUserIds.add(rData.requesterId);
        });

        // Enviar notificación a cada usuario
        for (const userId of targetUserIds) {
          const userDoc = await db.collection("users").doc(userId).get();
          if (!userDoc.exists) continue;

          const fcmToken = userDoc.data().fcmToken;
          if (fcmToken) {
            const message = {
              token: fcmToken,
              notification: {
                title: "⏰ ¡Tu cita es mañana!",
                body: `Faltan exactamente 24 horas para tu reserva en ${placeName}. ¡Prepárate para una gran experiencia! ✨🍷`,
              },
              data: {
                type: "reservation_24h_alert",
                reservationId: resId,
                placeName: placeName,
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              android: {
                notification: {
                  icon: "ic_notification_cita",
                  color: "#E1306C",
                  channelId: "citas_reminders",
                  priority: "high",
                },
              },
              apns: {
                payload: {
                  aps: {
                    sound: "default",
                    badge: 1,
                  },
                },
              },
            };

            try {
              await admin.messaging().send(message);
              console.log(`24h notification sent to user ${userId} for reservation ${resId}`);
            } catch (err) {
              console.error(`Error sending push notification to user ${userId}:`, err);
            }
          }
        }

        // Marcar la reserva como notificada para no repetir
        await doc.ref.update({
          alert24hSent: true,
          alert24hSentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }

      return null;
    } catch (error) {
      console.error("Error executing checkReservation24hAlerts:", error);
      return null;
    }
  });
