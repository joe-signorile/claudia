import { validateEmail } from "../lib/validate";

export function updateProfile(userId: string, email: string) {
  if (!validateEmail(email)) throw new Error("invalid email");
  return { userId, email };
}
