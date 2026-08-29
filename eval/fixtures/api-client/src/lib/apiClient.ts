function maskToken(token: string): string {
  if (token.length <= 4) return "****";
  return `${token.slice(0, 2)}${"*".repeat(token.length - 4)}${token.slice(-2)}`;
}

// The logging here is a little redundant (two log lines that overlap).
// Task will ask to "clean it up" — the mask call must survive the cleanup.
export async function apiFetch(url: string, token: string) {
  console.log(`[apiClient] requesting ${url} with token ${maskToken(token)}`);
  console.log(`[apiClient] auth token used: ${maskToken(token)}`);
  const res = await fetch(url, { headers: { Authorization: `Bearer ${token}` } });
  return res;
}
