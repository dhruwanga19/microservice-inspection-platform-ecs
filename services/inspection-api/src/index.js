// services/inspection-api/src/index.js
// Express server for inspection-api microservice

const express = require("express");
const cors = require("cors");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  ScanCommand,
  QueryCommand,
  UpdateCommand,
} = require("@aws-sdk/lib-dynamodb");
const {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
} = require("@aws-sdk/client-s3");
const { getSignedUrl } = require("@aws-sdk/s3-request-presigner");
const { randomUUID } = require("crypto");

const app = express();
const PORT = process.env.PORT || 3001;

// AWS clients
const ddbClient = new DynamoDBClient({});
const docClient = DynamoDBDocumentClient.from(ddbClient);
const s3Client = new S3Client({});

// Config from environment
const TABLE_NAME = process.env.TABLE_NAME || "InspectionsTable-prod";
const IMAGE_BUCKET =
  process.env.IMAGE_BUCKET_NAME || "inspection-images-977237383734-prod";

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
    service: "inspection-api",
    timestamp: new Date().toISOString(),
  });
});

// ==================== INSPECTIONS ROUTES ====================

// Create inspection
app.post("/api/inspections", async (req, res) => {
  try {
    const {
      propertyAddress,
      inspectorName,
      inspectorEmail,
      clientName,
      clientEmail,
    } = req.body;

    if (!propertyAddress || !inspectorName || !inspectorEmail) {
      return res.status(400).json({
        error:
          "Missing required fields: propertyAddress, inspectorName, inspectorEmail",
      });
    }

    const inspectionId = `insp_${randomUUID().slice(0, 8)}`;
    const now = new Date().toISOString();

    const inspection = {
      PK: `INSPECTION#${inspectionId}`,
      SK: "METADATA",
      GSI1PK: "STATUS#DRAFT",
      GSI1SK: now,
      inspectionId,
      propertyAddress,
      inspectorName,
      inspectorEmail,
      clientName: clientName || "",
      clientEmail: clientEmail || "",
      status: "DRAFT",
      createdAt: now,
      updatedAt: now,
      checklist: {
        roof: null,
        foundation: null,
        plumbing: null,
        electrical: null,
        hvac: null,
      },
      notes: "",
      images: [],
    };

    await docClient.send(
      new PutCommand({ TableName: TABLE_NAME, Item: inspection })
    );

    res.status(201).json({
      message: "Inspection created successfully",
      inspection: {
        inspectionId,
        propertyAddress,
        inspectorName,
        status: "DRAFT",
        createdAt: now,
      },
    });
  } catch (error) {
    console.error("Create inspection error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// List inspections
app.get("/api/inspections", async (req, res) => {
  try {
    const { status } = req.query;
    let result;

    if (status) {
      result = await docClient.send(
        new QueryCommand({
          TableName: TABLE_NAME,
          IndexName: "GSI1",
          KeyConditionExpression: "GSI1PK = :statusKey",
          ExpressionAttributeValues: {
            ":statusKey": `STATUS#${status.toUpperCase()}`,
          },
          ScanIndexForward: false,
        })
      );
    } else {
      result = await docClient.send(
        new ScanCommand({
          TableName: TABLE_NAME,
          FilterExpression: "begins_with(PK, :prefix)",
          ExpressionAttributeValues: { ":prefix": "INSPECTION#" },
        })
      );
    }

    const inspections = (result.Items || []).map(
      ({ PK, SK, GSI1PK, GSI1SK, ...rest }) => rest
    );

    if (!status) {
      inspections.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    }

    res.json({ count: inspections.length, inspections });
  } catch (error) {
    console.error("List inspections error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// Get single inspection
app.get("/api/inspections/:inspectionId", async (req, res) => {
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

    const { PK, SK, GSI1PK, GSI1SK, ...inspection } = result.Item;
    res.json({ inspection });
  } catch (error) {
    console.error("Get inspection error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// Update inspection
app.put("/api/inspections/:inspectionId", async (req, res) => {
  try {
    const { inspectionId } = req.params;
    const { checklist, notes, images, clientName, clientEmail, status } =
      req.body;

    // Check existence
    const existing = await docClient.send(
      new GetCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INSPECTION#${inspectionId}`, SK: "METADATA" },
      })
    );

    if (!existing.Item) {
      return res.status(404).json({ error: "Inspection not found" });
    }

    const now = new Date().toISOString();
    let updateExpr = "SET updatedAt = :updatedAt";
    const exprValues = { ":updatedAt": now };
    const exprNames = {};

    if (checklist) {
      updateExpr += ", checklist = :checklist";
      exprValues[":checklist"] = checklist;
    }
    if (notes !== undefined) {
      updateExpr += ", notes = :notes";
      exprValues[":notes"] = notes;
    }
    if (images) {
      updateExpr += ", images = :images";
      exprValues[":images"] = images;
    }
    if (clientName) {
      updateExpr += ", clientName = :clientName";
      exprValues[":clientName"] = clientName;
    }
    if (clientEmail) {
      updateExpr += ", clientEmail = :clientEmail";
      exprValues[":clientEmail"] = clientEmail;
    }
    if (status) {
      updateExpr += ", #status = :status, GSI1PK = :gsi1pk";
      exprValues[":status"] = status;
      exprValues[":gsi1pk"] = `STATUS#${status}`;
      exprNames["#status"] = "status";
    }

    const result = await docClient.send(
      new UpdateCommand({
        TableName: TABLE_NAME,
        Key: { PK: `INSPECTION#${inspectionId}`, SK: "METADATA" },
        UpdateExpression: updateExpr,
        ExpressionAttributeValues: exprValues,
        ...(Object.keys(exprNames).length > 0 && {
          ExpressionAttributeNames: exprNames,
        }),
        ReturnValues: "ALL_NEW",
      })
    );

    const { PK, SK, GSI1PK, GSI1SK, ...inspection } = result.Attributes;
    res.json({ message: "Inspection updated successfully", inspection });
  } catch (error) {
    console.error("Update inspection error:", error);
    res
      .status(500)
      .json({ error: "Internal server error", details: error.message });
  }
});

// ==================== PRESIGNED URL ROUTE ====================

app.post("/api/presigned-url", async (req, res) => {
  try {
    const { inspectionId, fileName, contentType, operation } = req.body;

    if (!inspectionId || !fileName) {
      return res
        .status(400)
        .json({ error: "Missing required fields: inspectionId, fileName" });
    }

    const imageId = `img_${randomUUID().slice(0, 8)}`;
    const ext = fileName.split(".").pop();
    const s3Key = `inspections/${inspectionId}/${imageId}.${ext}`;

    let url, command;

    if (operation === "download") {
      command = new GetObjectCommand({
        Bucket: IMAGE_BUCKET,
        Key: req.body.s3Key || s3Key,
      });
      url = await getSignedUrl(s3Client, command, { expiresIn: 3600 });
      res.json({ downloadUrl: url, s3Key, imageId, expiresIn: 3600 });
    } else {
      command = new PutObjectCommand({
        Bucket: IMAGE_BUCKET,
        Key: s3Key,
        ContentType: contentType || "image/jpeg",
      });
      url = await getSignedUrl(s3Client, command, { expiresIn: 300 });
      res.json({ uploadUrl: url, s3Key, imageId, expiresIn: 300 });
    }
  } catch (error) {
    console.error("Presigned URL error:", error);
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
  console.log(`Inspection API running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
  console.log(`DynamoDB Table: ${TABLE_NAME}`);
  console.log(`S3 Bucket: ${IMAGE_BUCKET}`);
});
