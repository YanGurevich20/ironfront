type PgsTokenExchangeResponse = {
  access_token?: string;
};

type PgsPlayerResponse = {
  playerId?: string;
  displayName?: string;
};

type VerifyPgsAuthCodeArgs = {
  serverAuthCode: string;
  webClientId: string;
  webClientSecret: string;
};

type VerifyPgsAuthCodeResult =
  | {
      success: true;
      providerSubject: string;
      displayName: string;
    }
  | {
      success: false;
      reason: "INVALID_PROVIDER_PROOF" | "PGS_PROVIDER_UNAVAILABLE";
    };

const GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token";
const PGS_PLAYER_ME_URL = "https://games.googleapis.com/games/v1/players/me";

export async function verifyPgsAuthCode(
  args: VerifyPgsAuthCodeArgs
): Promise<VerifyPgsAuthCodeResult> {
  if (!args.webClientId || !args.webClientSecret) {
    return { success: false, reason: "PGS_PROVIDER_UNAVAILABLE" };
  }

  const tokenBody = new URLSearchParams({
    code: args.serverAuthCode,
    client_id: args.webClientId,
    client_secret: args.webClientSecret,
    grant_type: "authorization_code",
    redirect_uri: ""
  });

  const tokenResponse = await fetch(GOOGLE_TOKEN_URL, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: tokenBody.toString()
  }).catch(() => null);
  if (!tokenResponse?.ok) {
    return { success: false, reason: "INVALID_PROVIDER_PROOF" };
  }

  const tokenJson = (await tokenResponse.json().catch(() => null)) as PgsTokenExchangeResponse | null;
  const accessToken = tokenJson?.access_token?.trim() ?? "";
  if (!accessToken) {
    return { success: false, reason: "INVALID_PROVIDER_PROOF" };
  }

  const playerResponse = await fetch(PGS_PLAYER_ME_URL, {
    method: "GET",
    headers: { authorization: `Bearer ${accessToken}` }
  }).catch(() => null);
  if (!playerResponse?.ok) {
    return { success: false, reason: "INVALID_PROVIDER_PROOF" };
  }

  const playerJson = (await playerResponse.json().catch(() => null)) as PgsPlayerResponse | null;
  const playerId = playerJson?.playerId?.trim() ?? "";
  if (!playerId) {
    return { success: false, reason: "INVALID_PROVIDER_PROOF" };
  }

  return {
    success: true,
    providerSubject: playerId,
    displayName: playerJson?.displayName?.trim() ?? ""
  };
}
