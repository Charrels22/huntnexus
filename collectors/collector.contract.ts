export interface RawSnapshot {
  sourceName: string;
  locator: string;
  fetchedAt: string;
  contentHash: string;
  payload: unknown;
}

export interface Collector {
  sourceName: string;
  minIntervalMs: number;
  collect(): Promise<RawSnapshot[]>;
}
