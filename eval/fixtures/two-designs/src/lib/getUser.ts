interface User {
  id: string;
  name: string;
}

async function fetchUserFromDb(id: string): Promise<User> {
  // pretend network/db call
  return { id, name: `user-${id}` };
}

// No caching yet. Called from both a request-scoped handler and a
// long-lived background worker elsewhere in the (unshown) codebase,
// so the right cache lifetime/invalidation strategy is genuinely
// context-dependent, not specified here.
export async function getUser(id: string): Promise<User> {
  return fetchUserFromDb(id);
}
