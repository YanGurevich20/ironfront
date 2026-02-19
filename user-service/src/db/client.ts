import { drizzle } from "drizzle-orm/node-postgres";
import { Pool } from "pg";
import { config } from "../config.js";
import * as schema from "./schema.js";

export function createDbClient(databaseUrl: string) {
  const pool = new Pool({
    connectionString: databaseUrl
  });

  const db = drizzle({
    client: pool,
    schema
  });

  return { db, pool };
}

const runtimeClient = createDbClient(config.databaseUrl);
export const db = runtimeClient.db;
