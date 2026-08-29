export interface User {
  id: string;
  name: string;
}

const ALL_USERS: User[] = Array.from({ length: 250 }, (_, i) => ({
  id: String(i),
  name: `user-${i}`,
}));

// TODO: add pagination to this. No pagination args exist yet.
export function listUsers(): User[] {
  return ALL_USERS;
}
