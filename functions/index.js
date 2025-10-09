const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendFCMNotification = onDocumentCreated(
    "fcm_queue/{docId}",
    async (event) => {
      const data = event.data.data();

      if (data.estado !== "pendiente") {
        console.log("Estado no es pendiente, ignorando");
        return null;
      }

      const tokens = data.tokens || [];
      if (tokens.length === 0) {
        console.log("No hay tokens para enviar");
        await event.data.ref.update({estado: "error", error: "No tokens"});
        return null;
      }

      const message = {
        notification: {
          title: data.notification.title || "Nueva notificación",
          body: data.notification.body || "",
        },
        data: data.data || {},
        tokens: tokens,
      };

      try {
        const response = await admin.messaging().sendEachForMulticast(message);

        console.log("Enviado exitosamente:", response.successCount);

        await event.data.ref.update({
          estado: "enviado",
          enviadoEn: admin.firestore.FieldValue.serverTimestamp(),
          resultado: {
            exitos: response.successCount,
            fallos: response.failureCount,
          },
        });

        return {success: response.successCount, failed: response.failureCount};
      } catch (error) {
        console.error("Error enviando notificaciones:", error);
        await event.data.ref.update({
          estado: "error",
          error: error.message,
        });
        return null;
      }
    },
);


