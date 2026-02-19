import { zValidator } from "@hono/zod-validator";
import { Hono } from "hono";
import { z } from "zod";
import { postExchangeHandler } from "./post_exchange.js";

const requestSchema = z.object({
  provider: z.enum(["dev", "pgs"]),
  proof: z.string().min(1),
  client: z.object({
    stage: z.enum(["dev", "prod"]),
    app_version: z.string().optional(),
    platform: z.string().optional()
  })
});

export const authRouter = new Hono();

authRouter.post(
  "/exchange",
  zValidator("json", requestSchema, (result, context) => {
    if (!result.success) {
      return context.json(
        { error: "INVALID_REQUEST", details: z.flattenError(result.error) },
        400
      );
    }
  }),
  postExchangeHandler
);
