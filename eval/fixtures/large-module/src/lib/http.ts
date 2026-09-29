export type Method = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";

export interface RequestOptions {
  method?: Method;
  headers?: Record<string, string>;
  body?: unknown;
  timeoutMs?: number;
  signal?: AbortSignal;
}

export interface RetryPolicy {
  maxAttempts: number;
  baseDelayMs: number;
  maxDelayMs: number;
  jitter: boolean;
}

export const DEFAULT_RETRY: RetryPolicy = {
  maxAttempts: 5,
  baseDelayMs: 200,
  maxDelayMs: 20_000,
  jitter: true,
};

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly url: string,
    readonly bodyText: string,
  ) {
    super(`${status} for ${url}`);
    this.name = "HttpError";
  }
}

export class TimeoutError extends Error {
  constructor(readonly url: string, readonly timeoutMs: number) {
    super(`timed out after ${timeoutMs}ms: ${url}`);
    this.name = "TimeoutError";
  }
}

export class TransportError extends Error {
  constructor(readonly url: string, readonly cause: unknown) {
    super(`transport failure: ${url}`);
    this.name = "TransportError";
  }
}

/**
 * Exponential backoff with full jitter, clamped to the policy ceiling.
 * Attempt numbers are 1-based: the first retry waits roughly baseDelayMs.
 */
export function backoffDelay(attempt: number, policy: RetryPolicy): number {
  const exponential = policy.baseDelayMs * 2 ** (attempt - 1);
  const clamped = Math.min(exponential, policy.maxDelayMs);
  if (!policy.jitter) {
    return clamped;
  }
  return Math.floor(Math.random() * clamped);
}

export function isRetryable(error: unknown): boolean {
  if (error instanceof TimeoutError || error instanceof TransportError) {
    return true;
  }
  if (error instanceof HttpError) {
    return error.status === 429 || error.status >= 500;
  }
  return false;
}

export interface JsonCodec {
  contentType: string;
  encode(value: unknown): BodyInit;
  decode(raw: string): unknown;
}

export const jsonCodec: JsonCodec = {
  contentType: "application/json",
  encode(value) {
    return JSON.stringify(value);
  },
  decode(raw) {
    return JSON.parse(raw) as unknown;
  },
};

export interface TextCodec {
  contentType: string;
  encode(value: string): BodyInit;
  decode(raw: string): string;
}

export const textCodec: TextCodec = {
  contentType: "text/plain",
  encode(value) {
    return value as BodyInit;
  },
  decode(raw) {
    return raw;
  },
};

export interface BytesCodec {
  contentType: string;
  encode(value: Uint8Array): BodyInit;
  decode(raw: string): Uint8Array;
}

export const bytesCodec: BytesCodec = {
  contentType: "application/octet-stream",
  encode(value) {
    return value as BodyInit;
  },
  decode(raw) {
    return new TextEncoder().encode(raw);
  },
};

export interface FormCodec {
  contentType: string;
  encode(value: Record<string, string>): BodyInit;
  decode(raw: string): Record<string, string>;
}

export const formCodec: FormCodec = {
  contentType: "application/x-www-form-urlencoded",
  encode(value) {
    return new URLSearchParams(value).toString();
  },
  decode(raw) {
    return Object.fromEntries(new URLSearchParams(raw));
  },
};

export function mergeHeaders(
  ...sources: Array<Record<string, string> | undefined>
): Record<string, string> {
  const merged: Record<string, string> = {};
  for (const source of sources) {
    if (!source) continue;
    for (const [key, value] of Object.entries(source)) {
      merged[key.toLowerCase()] = value;
    }
  }
  return merged;
}

export function joinUrl(base: string, path: string): string {
  if (/^https?:\/\//.test(path)) return path;
  return `${base.replace(/\/+$/, "")}/${path.replace(/^\/+/, "")}`;
}

export function withQuery(
  url: string,
  query?: Record<string, string | number | boolean | undefined>,
): string {
  if (!query) return url;
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value === undefined) continue;
    params.set(key, String(value));
  }
  const qs = params.toString();
  return qs ? `${url}${url.includes("?") ? "&" : "?"}${qs}` : url;
}

export function parseRetryAfter(header: string | null): number | null {
  if (!header) return null;
  const seconds = Number(header);
  if (Number.isFinite(seconds)) return seconds * 1000;
  const date = Date.parse(header);
  return Number.isNaN(date) ? null : Math.max(0, date - Date.now());
}

function sleep(ms: number, signal?: AbortSignal): Promise<void> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(resolve, ms);
    signal?.addEventListener("abort", () => {
      clearTimeout(timer);
      reject(new Error("aborted"));
    });
  });
}

export type RequestInterceptor = (
  url: string,
  options: RequestOptions,
) => RequestOptions | Promise<RequestOptions>;

export type ResponseInterceptor = (
  response: Response,
) => Response | Promise<Response>;

export class InterceptorChain {
  private readonly requestStage: RequestInterceptor[] = [];
  private readonly responseStage: ResponseInterceptor[] = [];

  onRequest(fn: RequestInterceptor): this {
    this.requestStage.push(fn);
    return this;
  }

  onResponse(fn: ResponseInterceptor): this {
    this.responseStage.push(fn);
    return this;
  }

  async applyRequest(url: string, options: RequestOptions): Promise<RequestOptions> {
    let current = options;
    for (const fn of this.requestStage) {
      current = await fn(url, current);
    }
    return current;
  }

  async applyResponse(response: Response): Promise<Response> {
    let current = response;
    for (const fn of this.responseStage) {
      current = await fn(current);
    }
    return current;
  }
}

export function bearerAuth(token: string): RequestInterceptor {
  return (_url, options) => ({
    ...options,
    headers: mergeHeaders(options.headers, { authorization: `Bearer ${token}` }),
  });
}

export function userAgent(value: string): RequestInterceptor {
  return (_url, options) => ({
    ...options,
    headers: mergeHeaders(options.headers, { "user-agent": value }),
  });
}

export function rejectOnError(): ResponseInterceptor {
  return async (response) => {
    if (response.ok) return response;
    throw new HttpError(response.status, response.url, await response.text());
  };
}

export interface ClientConfig {
  baseUrl: string;
  retry?: Partial<RetryPolicy>;
  defaultHeaders?: Record<string, string>;
  defaultTimeoutMs?: number;
}

export class HttpClient {
  private readonly retry: RetryPolicy;
  readonly interceptors = new InterceptorChain();

  constructor(private readonly config: ClientConfig) {
    this.retry = { ...DEFAULT_RETRY, ...config.retry };
  }

  async request(path: string, options: RequestOptions = {}): Promise<Response> {
    const url = joinUrl(this.config.baseUrl, path);
    let lastError: unknown;

    for (let attempt = 1; attempt <= this.retry.maxAttempts; attempt += 1) {
      try {
        return await this.attempt(url, options);
      } catch (error) {
        lastError = error;
        if (!isRetryable(error) || attempt === this.retry.maxAttempts) {
          throw error;
        }
        await sleep(backoffDelay(attempt, this.retry), options.signal);
      }
    }

    throw lastError;
  }

  private async attempt(url: string, options: RequestOptions): Promise<Response> {
    const resolved = await this.interceptors.applyRequest(url, {
      ...options,
      headers: mergeHeaders(this.config.defaultHeaders, options.headers),
      timeoutMs: options.timeoutMs ?? this.config.defaultTimeoutMs ?? 30_000,
    });

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), resolved.timeoutMs);
    try {
      const response = await fetch(url, {
        method: resolved.method ?? "GET",
        headers: resolved.headers,
        body: resolved.body === undefined ? undefined : jsonCodec.encode(resolved.body),
        signal: controller.signal,
      });
      return await this.interceptors.applyResponse(response);
    } catch (error) {
      if (controller.signal.aborted) {
        throw new TimeoutError(url, resolved.timeoutMs ?? 0);
      }
      throw new TransportError(url, error);
    } finally {
      clearTimeout(timer);
    }
  }

  async get<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const response = await this.request(path, {
      ...options,
      method: "GET",
      
    });
    return jsonCodec.decode(await response.text()) as T;
  }

  async delete<T>(path: string, options: RequestOptions = {}): Promise<T> {
    const response = await this.request(path, {
      ...options,
      method: "DELETE",
      
    });
    return jsonCodec.decode(await response.text()) as T;
  }

  async post<T>(path: string, body: unknown, options: RequestOptions = {}): Promise<T> {
    const response = await this.request(path, {
      ...options,
      method: "POST",
      body,
    });
    return jsonCodec.decode(await response.text()) as T;
  }

  async put<T>(path: string, body: unknown, options: RequestOptions = {}): Promise<T> {
    const response = await this.request(path, {
      ...options,
      method: "PUT",
      body,
    });
    return jsonCodec.decode(await response.text()) as T;
  }

  async patch<T>(path: string, body: unknown, options: RequestOptions = {}): Promise<T> {
    const response = await this.request(path, {
      ...options,
      method: "PATCH",
      body,
    });
    return jsonCodec.decode(await response.text()) as T;
  }
}

export interface Page<T> {
  items: T[];
  nextCursor: string | null;
}

export class Paginator<T> implements AsyncIterable<T> {
  constructor(
    private readonly client: HttpClient,
    private readonly path: string,
    private readonly pageSize = 100,
  ) {}

  async *[Symbol.asyncIterator](): AsyncIterator<T> {
    let cursor: string | null = null;
    do {
      const page = await this.client.get<Page<T>>(
        withQuery(this.path, { cursor: cursor ?? undefined, limit: this.pageSize }),
      );
      for (const item of page.items) {
        yield item;
      }
      cursor = page.nextCursor;
    } while (cursor);
  }

  async collect(limit = Infinity): Promise<T[]> {
    const out: T[] = [];
    for await (const item of this) {
      out.push(item);
      if (out.length >= limit) break;
    }
    return out;
  }
}

/**
 * Token bucket. Refills continuously; acquire() resolves once a token is
 * available, so callers can await it in a tight loop without busy-waiting.
 */
export class RateLimiter {
  private tokens: number;
  private lastRefill = Date.now();

  constructor(
    private readonly capacity: number,
    private readonly refillPerSecond: number,
  ) {
    this.tokens = capacity;
  }

  private refill(): void {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    this.tokens = Math.min(this.capacity, this.tokens + elapsed * this.refillPerSecond);
    this.lastRefill = now;
  }

  tryAcquire(): boolean {
    this.refill();
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }

  async acquire(signal?: AbortSignal): Promise<void> {
    while (!this.tryAcquire()) {
      const deficit = 1 - this.tokens;
      await sleep((deficit / this.refillPerSecond) * 1000, signal);
    }
  }
}

export function throttle(limiter: RateLimiter): RequestInterceptor {
  return async (_url, options) => {
    await limiter.acquire(options.signal);
    return options;
  };
}

export interface ServerSentEvent {
  event: string;
  data: string;
  id: string | null;
}

/**
 * Incremental SSE parser. Feed it chunks; it emits whole events only, holding
 * partial frames until the terminating blank line arrives.
 */
export class EventStreamParser {
  private buffer = "";

  push(chunk: string): ServerSentEvent[] {
    this.buffer += chunk;
    const events: ServerSentEvent[] = [];
    let boundary = this.buffer.indexOf("\n\n");
    while (boundary !== -1) {
      const frame = this.buffer.slice(0, boundary);
      this.buffer = this.buffer.slice(boundary + 2);
      const parsed = EventStreamParser.parseFrame(frame);
      if (parsed) events.push(parsed);
      boundary = this.buffer.indexOf("\n\n");
    }
    return events;
  }

  private static parseFrame(frame: string): ServerSentEvent | null {
    let event = "message";
    let id: string | null = null;
    const data: string[] = [];

    for (const line of frame.split("\n")) {
      if (!line || line.startsWith(":")) continue;
      const colon = line.indexOf(":");
      const field = colon === -1 ? line : line.slice(0, colon);
      const value = colon === -1 ? "" : line.slice(colon + 1).trimStart();
      if (field === "event") event = value;
      else if (field === "id") id = value;
      else if (field === "data") data.push(value);
    }

    return data.length ? { event, data: data.join("\n"), id } : null;
  }

  flush(): ServerSentEvent[] {
    const rest = this.buffer;
    this.buffer = "";
    const parsed = rest ? EventStreamParser.parseFrame(rest) : null;
    return parsed ? [parsed] : [];
  }
}

export async function* streamEvents(
  client: HttpClient,
  path: string,
  options: RequestOptions = {},
): AsyncGenerator<ServerSentEvent> {
  const response = await client.request(path, {
    ...options,
    headers: mergeHeaders(options.headers, { accept: "text/event-stream" }),
  });
  const body = response.body;
  if (!body) return;

  const parser = new EventStreamParser();
  const decoder = new TextDecoder();
  const reader = body.getReader();

  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      for (const event of parser.push(decoder.decode(value, { stream: true }))) {
        yield event;
      }
    }
    for (const event of parser.flush()) {
      yield event;
    }
  } finally {
    reader.releaseLock();
  }
}

export function createClient(config: ClientConfig): HttpClient {
  return new HttpClient(config);
}
