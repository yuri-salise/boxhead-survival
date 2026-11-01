import express from "express";

const app = express();
app.use(express.json());

const version = process.env.APP_VERSION || "dev";

const leaderboard = [
  { rank: 1, callsign: "ALPHA_ACTUAL", score: 2840, wave: 14 },
  { rank: 2, callsign: "BRAVO_MEDIC", score: 2190, wave: 11 },
  { rank: 3, callsign: "DEADBLOCK_VET", score: 1750, wave: 9 }
];

app.get("/", (_req, res) => {
  res.type("html").send(`<!doctype html>
<html>
  <head><meta charset="utf-8"><title>ITSD 85 CI/CD — Dead Block: Survival</title></head>
  <body style="font-family: sans-serif; max-width: 680px; margin: 40px auto; background: #121519; color: #e8eaed;">
    <h1>ITSD 85 — Automated CI/CD &amp; Dead Block: Survival Server</h1>
    <p>Status: <strong>running</strong></p>
    <p>Version: <code>${version}</code></p>
    <p>Game Package: <code>com.itsd85.deadblock.survival</code></p>
  </body>
</html>`);
});

app.get("/health", (_req, res) => {
  res.status(200).json({ status: "ok", version });
});

app.get("/api/add", (req, res) => {
  const a = Number(req.query.a);
  const b = Number(req.query.b);
  if (Number.isNaN(a) || Number.isNaN(b)) {
    return res.status(400).json({ error: "Query params a and b must be numbers" });
  }
  return res.json({ a, b, sum: a + b });
});

app.get("/api/leaderboard", (_req, res) => {
  res.json({ status: "ok", leaderboard });
});

app.post("/v2/account/authenticate/device", (req, res) => {
  const id = (req.body && req.body.id) ? String(req.body.id) : "device_anon";
  const token = Buffer.from(`${id}:${Date.now()}`).toString("base64");
  res.status(200).json({ token, created: true });
});

export default app;
