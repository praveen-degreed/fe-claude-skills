export function formatDuration(totalSeconds: number): string {
  return `${Math.floor(totalSeconds / 60)}m`;
}
