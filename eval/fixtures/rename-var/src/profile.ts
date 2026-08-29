import { getSessionOwner } from "./session";

export function renderProfile(usr: { id: string; name: string }) {
  const ownerId = getSessionOwner(usr);
  return `${usr.name} (${ownerId})`;
}
