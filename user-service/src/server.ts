import { serve } from "@hono/node-server";
import { Hono } from "hono";
import { config } from "./config.js";
import { authRouter } from "./routes/auth/route.js";
import { meRouter } from "./routes/me/route.js";

const app = new Hono();

app.get("/healthz", (context) => {
  return context.json({ ok: true, stage: config.stage });
});

app.route("/auth", authRouter);
app.route("/me", meRouter);

app.onError((error, context) => {
  console.error("[http] unhandled error", error);
  return context.json({ error: "INTERNAL_ERROR" }, 500);
});

serve({
  fetch: app.fetch,
  port: config.port
});

console.log(`[user-service] listening on :${config.port} stage=${config.stage}`);
