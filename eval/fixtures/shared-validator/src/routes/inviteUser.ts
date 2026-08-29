import { validateEmail } from "../lib/validate";

export function inviteUser(email: string) {
  if (!validateEmail(email)) throw new Error("invalid email");
  return { invited: email };
}
