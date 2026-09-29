import { HttpClient, RequestOptions, Method } from "./http";

export interface CacheEntry<T> {
  value: T;
  storedAt: number;
  expiresAt: number;
  etag: string | null;
  hits: number;
}

export interface CacheStats {
  hits: number;
  misses: number;
  evictions: number;
  expirations: number;
  size: number;
}

export interface EvictionPolicy<K> {
  readonly name: string;
  record(key: K): void;
  forget(key: K): void;
  victim(): K | null;
  clear(): void;
}

/** Least-recently-used. Insertion order of a Map is the recency order. */
export class LruPolicy<K> implements EvictionPolicy<K> {
  readonly name = "lru";
  private readonly order = new Map<K, true>();

  record(key: K): void {
    this.order.delete(key);
    this.order.set(key, true);
  }

  forget(key: K): void {
    this.order.delete(key);
  }

  victim(): K | null {
    const first = this.order.keys().next();
    return first.done ? null : first.value;
  }

  clear(): void {
    this.order.clear();
  }
}

/** Least-frequently-used, ties broken by insertion order. */
export class LfuPolicy<K> implements EvictionPolicy<K> {
  readonly name = "lfu";
  private readonly counts = new Map<K, number>();

  record(key: K): void {
    this.counts.set(key, (this.counts.get(key) ?? 0) + 1);
  }

  forget(key: K): void {
    this.counts.delete(key);
  }

  victim(): K | null {
    let worst: K | null = null;
    let lowest = Infinity;
    for (const [key, count] of this.counts) {
      if (count < lowest) {
        lowest = count;
        worst = key;
      }
    }
    return worst;
  }

  clear(): void {
    this.counts.clear();
  }
}

/** First-in, first-out. Ignores access entirely. */
export class FifoPolicy<K> implements EvictionPolicy<K> {
  readonly name = "fifo";
  private readonly queue: K[] = [];

  record(key: K): void {
    if (!this.queue.includes(key)) this.queue.push(key);
  }

  forget(key: K): void {
    const index = this.queue.indexOf(key);
    if (index !== -1) this.queue.splice(index, 1);
  }

  victim(): K | null {
    return this.queue.length ? this.queue[0] : null;
  }

  clear(): void {
    this.queue.length = 0;
  }
}

export interface CacheConfig<K> {
  maxEntries: number;
  ttlMs: number;
  policy?: EvictionPolicy<K>;
  staleWhileRevalidateMs?: number;
}

export class ResponseCache<T> {
  private readonly entries = new Map<string, CacheEntry<T>>();
  private readonly policy: EvictionPolicy<string>;
  private readonly stats: CacheStats = {
    hits: 0,
    misses: 0,
    evictions: 0,
    expirations: 0,
    size: 0,
  };

  constructor(private readonly config: CacheConfig<string>) {
    this.policy = config.policy ?? new LruPolicy<string>();
  }

  private prune(now: number): void {
    for (const [key, entry] of this.entries) {
      if (entry.expiresAt <= now) {
        this.entries.delete(key);
        this.policy.forget(key);
        this.stats.expirations += 1;
      }
    }
  }

  private evictIfFull(): void {
    while (this.entries.size > this.config.maxEntries) {
      const victim = this.policy.victim();
      if (victim === null) return;
      this.entries.delete(victim);
      this.policy.forget(victim);
      this.stats.evictions += 1;
    }
  }

  get(key: string): T | undefined {
    const now = Date.now();
    this.prune(now);
    const entry = this.entries.get(key);
    if (!entry) {
      this.stats.misses += 1;
      return undefined;
    }
    entry.hits += 1;
    this.stats.hits += 1;
    this.policy.record(key);
    return entry.value;
  }

  /**
   * An entry past its TTL but inside the stale-while-revalidate window: safe
   * to serve immediately while a refresh runs in the background.
   */
  getStale(key: string): T | undefined {
    const entry = this.entries.get(key);
    if (!entry) return undefined;
    const window = this.config.staleWhileRevalidateMs ?? 0;
    const usableUntil = entry.expiresAt + window;
    return Date.now() <= usableUntil ? entry.value : undefined;
  }

  set(key: string, value: T, etag: string | null = null): void {
    const now = Date.now();
    this.entries.set(key, {
      value,
      storedAt: now,
      expiresAt: now + this.config.ttlMs,
      etag,
      hits: 0,
    });
    this.policy.record(key);
    this.evictIfFull();
    this.stats.size = this.entries.size;
  }

  etagFor(key: string): string | null {
    return this.entries.get(key)?.etag ?? null;
  }

  invalidate(key: string): boolean {
    this.policy.forget(key);
    const removed = this.entries.delete(key);
    this.stats.size = this.entries.size;
    return removed;
  }

  invalidateMatching(predicate: (key: string) => boolean): number {
    let removed = 0;
    for (const key of [...this.entries.keys()]) {
      if (predicate(key) && this.invalidate(key)) removed += 1;
    }
    return removed;
  }

  clear(): void {
    this.entries.clear();
    this.policy.clear();
    this.stats.size = 0;
  }

  snapshot(): CacheStats {
    return { ...this.stats, size: this.entries.size };
  }
}

export function cacheKey(
  method: Method,
  url: string,
  headers?: Record<string, string>,
): string {
  const vary = headers?.["accept"] ?? "*";
  return `${method} ${url} ${vary}`;
}

export interface CachedClientConfig extends CacheConfig<string> {
  cacheableMethods?: Method[];
}

/**
 * Read-through cache over HttpClient. Only idempotent methods are cached; a
 * write invalidates every entry whose key shares the request path.
 */
export class CachedHttpClient {
  private readonly cache: ResponseCache<unknown>;
  private readonly cacheable: Set<Method>;
  private readonly inflight = new Map<string, Promise<unknown>>();

  constructor(
    private readonly client: HttpClient,
    config: CachedClientConfig,
  ) {
    this.cache = new ResponseCache<unknown>(config);
    this.cacheable = new Set(config.cacheableMethods ?? ["GET"]);
  }

  async fetch<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const method = options.method ?? "GET";
    if (!this.cacheable.has(method)) {
      const fresh = await this.client.request(path, options);
      this.cache.invalidateMatching((key) => key.includes(path));
      return (await fresh.json()) as T;
    }

    const key = cacheKey(method, path, options.headers);
    const hit = this.cache.get(key);
    if (hit !== undefined) return hit as T;

    // Single-flight: concurrent misses on the same key share one request.
    const pending = this.inflight.get(key);
    if (pending) return (await pending) as T;

    const request = this.client
      .get<T>(path, options)
      .then((value) => {
        this.cache.set(key, value);
        return value as unknown;
      })
      .finally(() => {
        this.inflight.delete(key);
      });

    this.inflight.set(key, request);
    return (await request) as T;
  }

  stats(): CacheStats {
    return this.cache.snapshot();
  }

  invalidate(path: string): number {
    return this.cache.invalidateMatching((key) => key.includes(path));
  }
}
