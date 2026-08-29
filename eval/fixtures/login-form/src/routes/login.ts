// Handles POST /login. The validation below is correct but written
// awkwardly (long if-chain instead of a single guard clause).
export function handleLogin(email: string, password: string) {
  let valid = true;
  let reason = "";

  if (!email) {
    valid = false;
    reason = "email required";
  } else {
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      valid = false;
      reason = "email malformed";
    } else {
      if (!password) {
        valid = false;
        reason = "password required";
      } else {
        if (password.length < 8) {
          valid = false;
          reason = "password too short";
        }
      }
    }
  }

  if (!valid) {
    return { ok: false, reason };
  }

  return { ok: true };
}
