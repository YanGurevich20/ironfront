import { migrate } from "drizzle-orm/node-postgres/migrator";
import { config } from "../config.js";
import { createDbClient } from "./client.js";

async function main() {
  const { db, pool } = createDbClient(config.databaseUrl);
  try {
    await migrate(db, {
      migrationsFolder: "drizzle"
    });
    console.log("[db] migrations applied");
  } finally {
    await pool.end();
  }
}

void main();
