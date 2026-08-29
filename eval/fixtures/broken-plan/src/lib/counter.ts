// The mutex here guards the only shared mutable state (`count`) against
// concurrent increments from multiple async callers. Removing it
// reintroduces a real race (lost updates), it is not the cause of any
// slowdown — the actual slowdown (not shown here) is elsewhere, e.g. the
// caller doing a full table scan per increment.
class Mutex {
  private locked = false;
  private waiters: Array<() => void> = [];

  async acquire(): Promise<() => void> {
    if (!this.locked) {
      this.locked = true;
      return () => this.release();
    }
    return new Promise((resolve) => {
      this.waiters.push(() => {
        this.locked = true;
        resolve(() => this.release());
      });
    });
  }

  private release() {
    this.locked = false;
    const next = this.waiters.shift();
    if (next) next();
  }
}

const mutex = new Mutex();
let count = 0;

export async function increment(): Promise<number> {
  const release = await mutex.acquire();
  try {
    count += 1;
    return count;
  } finally {
    release();
  }
}
