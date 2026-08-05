/**
 * Server-anchored clock.
 *
 * The naive implementation — subtract 100ms every tick — is wrong twice over.
 * It accumulates rounding error for the whole game, and browsers throttle
 * background tabs to roughly one timer callback per minute, so a player who
 * switches tabs comes back to a clock that is minutes adrift.
 *
 * So we never accumulate. The server's banked time is stored with the moment we
 * received it, and the remaining time is *computed* from that anchor on every
 * frame. Throttling then only affects how often the number is repainted, never
 * what it says.
 *
 * Anchoring on receipt (rather than on a server timestamp) also means P0 needs
 * no clock-offset estimation: we are measuring elapsed time locally with a
 * monotonic source, not comparing two wall clocks. The residual error is the
 * one-way network delay of the last update — corrected in P2 by lag
 * compensation, and harmless at rapid time controls.
 */

export type Colour = 'white' | 'black';

export class Clock {
  /** Banked milliseconds as last reported by the server. */
  private banked: Record<Colour, number> = { white: 0, black: 0 };
  /** performance.now() when that report arrived — monotonic, unlike Date.now(). */
  private anchor = 0;
  private running = false;
  private turn: Colour = 'white';
  private timed = false;

  get isTimed(): boolean {
    return this.timed;
  }

  /** Apply a clock payload from the server. `null` means an untimed game. */
  update(clock: { white: number; black: number } | null | undefined, turn: Colour): void {
    this.turn = turn;
    if (!clock) {
      this.timed = false;
      return;
    }
    this.timed = true;
    this.banked.white = clock.white;
    this.banked.black = clock.black;
    this.anchor = performance.now();
  }

  /** The clock only burns while the game is actually in progress. */
  setRunning(running: boolean): void {
    if (running === this.running) return;
    // Bank whatever the side to move has spent so far before changing state,
    // otherwise a pause would retroactively refund it.
    if (this.timed && this.running) {
      this.banked[this.turn] = this.remaining(this.turn);
      this.anchor = performance.now();
    }
    this.running = running;
    if (running) this.anchor = performance.now();
  }

  /** True remaining milliseconds for a colour, right now. */
  remaining(colour: Colour): number {
    if (!this.timed) return 0;
    const banked = this.banked[colour];
    if (!this.running || colour !== this.turn) return Math.max(0, banked);
    return Math.max(0, banked - (performance.now() - this.anchor));
  }

  /** True when the side to move has run out — the client's cue to claim a flag. */
  flagged(): Colour | null {
    if (!this.timed || !this.running) return null;
    return this.remaining(this.turn) <= 0 ? this.turn : null;
  }
}

/** `6:04` normally, `9.7` under ten seconds — the convention players expect. */
export function formatClock(ms: number): string {
  const total = Math.max(0, ms);
  if (total < 10_000) return (total / 1000).toFixed(1);
  const secs = Math.floor(total / 1000);
  return `${Math.floor(secs / 60)}:${String(secs % 60).padStart(2, '0')}`;
}
