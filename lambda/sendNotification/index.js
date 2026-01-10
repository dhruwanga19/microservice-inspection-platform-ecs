// lambda/sendNotification/index.js
// Lambda function triggered by SQS to send notifications
// In production, integrate with SES, SendGrid, or similar

exports.handler = async (event) => {
  console.log("Event:", JSON.stringify(event, null, 2));

  const results = [];

  for (const record of event.Records) {
    try {
      const body = JSON.parse(record.body);
      // SNS wraps the message, so parse again
      const message = JSON.parse(body.Message);

      console.log("Processing notification:", message);

      const {
        type,
        inspectionId,
        propertyAddress,
        inspectorEmail,
        clientEmail,
        generatedAt,
      } = message;

      if (type === "REPORT_GENERATED") {
        // In production, send actual emails via SES
        // For demo, we log what would be sent

        const inspectorNotification = {
          to: inspectorEmail,
          subject: `Inspection Report Ready - ${propertyAddress}`,
          body: `
            Your inspection report for ${propertyAddress} has been generated.
            
            Inspection ID: ${inspectionId}
            Generated At: ${new Date(generatedAt).toLocaleString()}
            
            You can view the full report in the inspection platform.
          `,
        };

        const clientNotification = clientEmail
          ? {
              to: clientEmail,
              subject: `Property Inspection Report Available - ${propertyAddress}`,
              body: `
            The inspection report for ${propertyAddress} is now available.
            
            Inspection ID: ${inspectionId}
            Generated At: ${new Date(generatedAt).toLocaleString()}
            
            Please log in to view the detailed report.
          `,
            }
          : null;

        console.log("Would send to inspector:", inspectorNotification);
        if (clientNotification) {
          console.log("Would send to client:", clientNotification);
        }

        // Production implementation example:
        // const { SESClient, SendEmailCommand } = require('@aws-sdk/client-ses');
        // const sesClient = new SESClient({});
        // await sesClient.send(new SendEmailCommand({
        //   Source: 'noreply@yourdomain.com',
        //   Destination: { ToAddresses: [inspectorEmail] },
        //   Message: {
        //     Subject: { Data: inspectorNotification.subject },
        //     Body: { Text: { Data: inspectorNotification.body } }
        //   }
        // }));

        results.push({
          inspectionId,
          status: "notifications_logged",
          recipients: [inspectorEmail, clientEmail].filter(Boolean),
        });
      }
    } catch (error) {
      console.error("Error processing record:", error);
      results.push({
        recordId: record.messageId,
        status: "error",
        error: error.message,
      });
    }
  }

  console.log("Processing complete:", results);

  return {
    statusCode: 200,
    body: JSON.stringify({ processed: results.length, results }),
  };
};
