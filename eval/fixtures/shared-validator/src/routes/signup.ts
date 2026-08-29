import { validateEmail } from "../lib/validate";

export function signup(email: string) {
  if (!validateEmail(email)) throw new Error("invalid email");
  return { email };
}
