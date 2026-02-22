import type { AccountLoadout } from "./db/schema.js";

const STARTER_TANK_ID = "m4a1_sherman";
const STARTER_FIRST_SHELL_ID = "m4a1_sherman.m75";
const STARTER_SHELL_CAPACITY = 70;

export const STARTER_LOADOUT: AccountLoadout = {
  selected_tank_id: STARTER_TANK_ID,
  tanks: {
    [STARTER_TANK_ID]: {
      unlocked_shell_ids: [STARTER_FIRST_SHELL_ID],
      shell_loadout_by_id: { [STARTER_FIRST_SHELL_ID]: STARTER_SHELL_CAPACITY }
    }
  }
};

export function ensureStarterLoadout(loadout: AccountLoadout): AccountLoadout {
  if (loadout.tanks && Object.keys(loadout.tanks).length > 0) {
    return loadout;
  }
  return structuredClone(STARTER_LOADOUT);
}
