import { test } from "node:test";
import assert from "node:assert/strict";
import request from "supertest";
import app from "../src/app.js";

test("GET /health returns status ok", async () => {
  const res = await request(app).get("/health");
  assert.equal(res.status, 200);
  assert.equal(res.body.status, "ok");
  assert.ok(res.body.version);
});

test("GET / returns HTML page", async () => {
  const res = await request(app).get("/");
  assert.equal(res.status, 200);
  assert.match(res.text, /ITSD 85/);
});

test("GET /api/add adds two numbers", async () => {
  const res = await request(app).get("/api/add?a=7&b=5");
  assert.equal(res.status, 200);
  assert.equal(res.body.sum, 12);
});

test("GET /api/add rejects non-numeric input", async () => {
  const res = await request(app).get("/api/add?a=foo&b=5");
  assert.equal(res.status, 400);
});

test("POST /v2/account/authenticate/device issues session token", async () => {
  const res = await request(app)
    .post("/v2/account/authenticate/device?create=true")
    .send({ id: "deadblock_device_001" });
  assert.equal(res.status, 200);
  assert.ok(res.body.token);
});
