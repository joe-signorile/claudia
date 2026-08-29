// Bug: accepts anything with an "@" and at least one character after it,
// e.g. "a@b" passes. Used by three call sites.
export function validateEmail(email: string): boolean {
  return email.includes("@") && email.indexOf("@") < email.length - 1;
}
