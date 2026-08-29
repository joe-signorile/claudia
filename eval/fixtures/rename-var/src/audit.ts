export function logAccess(usr: { id: string }, action: string) {
  console.log(`${usr.id} performed ${action}`);
}
