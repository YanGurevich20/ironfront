export type Stage = "dev" | "prod";
export type AuthProvider = "dev" | "pgs";

export type AuthExchangeRequest = {
  provider: AuthProvider;
  proof: string;
};

export type AuthExchangeResponse = {
  account_id: string;
  session_token: string;
  expires_at_unix: number;
  is_new_account: boolean;
};
