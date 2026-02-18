export type Stage = "dev" | "prod";
export type AuthProvider = "dev" | "pgs";

export type AuthExchangeRequest = {
  provider: AuthProvider;
  proof: string;
  client: {
    stage: Stage;
    app_version?: string;
    platform?: string;
  };
};

export type Profile = {
  account_id: string;
  username: string;
  display_name: string;
  progression: Record<string, unknown>;
  economy: Record<string, unknown>;
  loadout: Record<string, unknown>;
};

export type AuthExchangeResponse = {
  account_id: string;
  session_token: string;
  expires_at_unix: number;
  is_new_account: boolean;
  profile: {
    username: string;
    display_name: string;
  };
};
