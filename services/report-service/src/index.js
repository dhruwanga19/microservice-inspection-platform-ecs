// services/report-service/src/index.js
// Express server for report-service microservice

const express = require("express");
const cors = require("cors");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  GetCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const { SNSClient, PublishCommand } = require("@aws-sdk/client-sns");

const app = express();
const PORT = process.env.PORT || 3002;

// AWS clients
const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const snsClient = new SNSClient({});

// Config from environment
const TABLE_NAME = process.env.TABLE_NAME;
const SNS_TOPIC_ARN = process.env.SNS_TOPIC_ARN;

// Middleware
app.use(cors());
app.use(express.json());

// Request logging
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} ${req.method} ${req.path}`);
  next();
});

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    service: "report-service",
    timestamp: new Date().toISOString(),
  });
});

// Helper function to calculate overall condition
function calculateOverallCondition(checklist) {
  const values = Object.values(checklist);
  const scores = { Good: 3, Fair: 2, Poor: 1 };
  const total = values.reduce((sum, v) => sum + (scores[v] || 0), 0);
  const avg = total / values.length;
  if (avg >= 2.5) return "Good";
  if (avg >= 1.5) return "Fair";
  return "Poor";
}

// ==================== REPORT ROUTES ====================

// Generate report for an inspection
app.post("/api/reports/:inspectionId", async (req, res) => {
  try {
    const { inspectionId } = req.params;

    // Fetch inspection data
    const result = await docClient.send(
      new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INSPECTION#${inspectionId}`, SK: "METADATA" },
      })
    );

    if (!result.Item) {
      return res.status(404).json({ error: "Inspection not found" });
    }

    const inspection = result.Item;

    // Validate checklist is complete
    if (
      !inspection.checklist ||
      Object.values(inspection.checklist).some((v) => v === null)
    ) {
      return res
        .status(400)
        .json({ error: "Inspection checklist is incomplete" });
    }

    const now = new Date().toISOString();

    // Generate report object
    const report = {
      reportId: `report_${inspectionId}`,
      inspectionId,
      generatedAt: now,
      propertyAddress: inspection.propertyAddress,
      inspector: {
        name: inspection.inspectorName,
        email: inspection.inspectorEmail,
      },
      client: {
        name: inspection.clientName,
        email: inspection.clientEmail,
      },
      summary: {
        checklist: inspection.checklist,
        overallCondition: calculateOverallCondition(inspection.checklist),
        notes: inspection.notes,
        totalImages: inspection.images?.length || 0,
      },
      images: inspection.images || [],
    };

    // Update inspection status
    await docClient.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INSPECTION#${inspectionId}`, SK: "METADATA" },
        UpdateExpression:
          "SET #status = :status, GSI1PK = :gsi1pk, reportGeneratedAt = :reportGenAt, updatedAt = :updatedAt",
        ExpressionAttributeNames: { "#status": "status" },
        ExpressionAttributeValues: {
          ":status": "REPORT_GENERATED",
          ":gsi1pk": "STATUS#REPORT_GENERATED",
          ":reportGenAt": now,
          ":updatedAt": now,
        },
      })
    );

    // Publish to SNS for async notification
    if (SNS_TOPIC_ARN) {
      try {
        await snsClient.send(
          new PublishCommand({
            TopicArn: SNS_TOPIC_ARN,
            Subject: "Inspection Report Generated",
            Message: JSON.stringify({
              type: "REPORT_GENERATED",
              inspectionId,
              reportId: report.reportId,
              propertyAddress: inspection.propertyAddress,
              inspectorEmail: inspection.inspectorEmail,
              clientEmail: inspection.clientEmail,
              generatedAt: now,
            }),
            MessageAttributes: {
              eventType: {
                DataType: "String",
                StringValue: "REPORT_GENERATED",
              },
            },
          })
        );
        console.log("SNS notification sent successfully");
      } catch (snsError) {
        console.error("SNS publish error (non-fatal):", snsError);
        // Don't fail the request if SNS fails
      }
    } else {
      console.warn("SNS_TOPIC_ARN not configured, skipping notification");
    }

    res.json({ message: "Report generated successfully", report });
  } catch (error) {
    console.error("Generate report error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// Get report for an inspection (retrieves the inspection with report data)
app.get("/api/reports/:inspectionId", async (req, res) => {
  try {
    const { inspectionId } = req.params;

    const result = await docClient.send(
      new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INSPECTION#${inspectionId}`, SK: "METADATA" },
      })
    );

    if (!result.Item) {
      return res.status(404).json({ error: "Inspection not found" });
    }

    const inspection = result.Item;

    if (inspection.status !== "REPORT_GENERATED") {
      return res
        .status(400)
        .json({ error: "Report has not been generated for this inspection" });
    }

    // Reconstruct report from inspection data
    const report = {
      reportId: `report_${inspectionId}`,
      inspectionId,
      generatedAt: inspection.reportGeneratedAt,
      propertyAddress: inspection.propertyAddress,
      inspector: {
        name: inspection.inspectorName,
        email: inspection.inspectorEmail,
      },
      client: {
        name: inspection.clientName,
        email: inspection.clientEmail,
      },
      summary: {
        checklist: inspection.checklist,
        overallCondition: calculateOverallCondition(inspection.checklist),
        notes: inspection.notes,
        totalImages: inspection.images?.length || 0,
      },
      images: inspection.images || [],
    };

    res.json({ report });
  } catch (error) {
    console.error("Get report error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res
    .status(500)
    .json({ error: "Internal server error", details: err.message });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: "Not found", path: req.path });
});

// Start server
app.listen(PORT, "0.0.0.0", () => {
  console.log(`Report Service running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`DynamoDB Table: ${TABLE_NAME}`);
  console.log(`SNS Topic: ${SNS_TOPIC_ARN || "NOT CONFIGURED"}`);
});
