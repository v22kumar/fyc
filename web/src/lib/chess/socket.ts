/**
 * Game socket — the transport layer for a live board.
 *
 * The old telecast page had an empty `ws.onclose`, so a single dropped frame
 * ended the game for that viewer permanently. A player socket cannot behave
 * that way: a train tunnel must not cost someone a won position.
 *
 * Responsibilities:
 *  - reconnect with exponential backoff and jitter
 *  - re-sync on every (re)connect, so the board is never trusted after a gap
 *  - queue outbound messages while offline and flush them on reconnect
 *  - heartbeat, so a half-open socket is detected instead of silently hanging
 */

export type Msg = Record<string, any>;
type Handler = (msg: Msg) => void;

const PING_INTERVAL_MS = 20_000;
const PONG_GRACE_MS = 10_000;
const BACKOFF_BASE_MS = 500;
const BACKOFF_MAX_MS = 15_000;

export class GameSocket {
  private ws: WebSocket | null = null;
  private handlers = new Map<string, Set<Handler>>();
  private outbox: Msg[] = [];
  private attempt = 0;
  private closedByUs = false;
  private pingTimer: number | null = null;
  private pongTimer: number | null = null;

  constructor(private url: string) {}

  on(type: string, fn: Handler): void {
    if (!this.handlers.has(type)) this.handlers.set(type, new Set());
    this.handlers.get(type)!.add(fn);
  }

  private emit(type: string, msg: Msg): void {
    this.handlers.get(type)?.forEach((fn) => {
      try {
        fn(msg);
      } catch (e) {
        console.error('[chess-socket] handler failed', type, e);
      }
    });
  }

  connect(): void {
    this.closedByUs = false;
    let ws: WebSocket;
    try {
      ws = new WebSocket(this.url);
    } catch {
      this.scheduleReconnect();
      return;
    }
    this.ws = ws;

    ws.onopen = () => {
      this.attempt = 0;
      this.emit('_open', {});
      // Always ask for the authoritative position on (re)connect. Anything we
      // held locally may be stale by an unknown number of moves.
      this.sendNow({ type: 'sync' });
      this.outbox.splice(0).forEach((m) => this.sendNow(m));
      this.startHeartbeat();
    };

    ws.onmessage = (ev) => {
      let msg: Msg;
      try {
        msg = JSON.parse(ev.data);
      } catch {
        return;
      }
      if (msg.type === 'pong') {
        this.clearPongTimer();
        return;
      }
      this.emit(msg.type, msg);
      this.emit('*', msg);
    };

    ws.onclose = () => {
      this.stopHeartbeat();
      this.ws = null;
      if (this.closedByUs) return;
      this.emit('_offline', {});
      this.scheduleReconnect();
    };

    ws.onerror = () => {
      // onclose always follows; reconnection is handled there.
    };
  }

  /** Queued if the socket is down, so a move made mid-drop is never lost. */
  send(msg: Msg): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) this.sendNow(msg);
    else this.outbox.push(msg);
  }

  private sendNow(msg: Msg): void {
    try {
      this.ws?.send(JSON.stringify(msg));
    } catch {
      this.outbox.push(msg);
    }
  }

  close(): void {
    this.closedByUs = true;
    this.stopHeartbeat();
    this.ws?.close();
    this.ws = null;
  }

  private scheduleReconnect(): void {
    // Full jitter: avoids every client in a tournament reconnecting in lockstep
    // and hammering the server the moment it comes back.
    const ceiling = Math.min(BACKOFF_MAX_MS, BACKOFF_BASE_MS * 2 ** this.attempt);
    const delay = Math.random() * ceiling;
    this.attempt = Math.min(this.attempt + 1, 10);
    window.setTimeout(() => this.connect(), delay);
  }

  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.pingTimer = window.setInterval(() => {
      this.sendNow({ type: 'ping' });
      // A socket that accepts writes but never answers is worse than a closed
      // one — it looks alive while the game silently stalls. Force a reconnect.
      if (this.pongTimer === null) {
        this.pongTimer = window.setTimeout(() => {
          this.pongTimer = null;
          this.ws?.close();
        }, PONG_GRACE_MS);
      }
    }, PING_INTERVAL_MS);
  }

  private clearPongTimer(): void {
    if (this.pongTimer !== null) {
      clearTimeout(this.pongTimer);
      this.pongTimer = null;
    }
  }

  private stopHeartbeat(): void {
    if (this.pingTimer !== null) clearInterval(this.pingTimer);
    this.pingTimer = null;
    this.clearPongTimer();
  }
}
