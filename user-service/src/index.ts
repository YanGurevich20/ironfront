import express from "express";
import { config } from "./config.js";
import { authExchangeRouter } from "./routes/auth_exchange.js";
import { meRouter } from "./routes/me.js";

const app = express();
app.use(express.json());

app.get("/healthz", (_req, res) => {
  res.status(200).json({ ok: true, stage: config.stage });
});

app.use(authExchangeRouter);
app.use(meRouter);

app.listen(config.port, () => {
  console.log(`[user-service] listening on :${config.port} stage=${config.stage}`);
});
