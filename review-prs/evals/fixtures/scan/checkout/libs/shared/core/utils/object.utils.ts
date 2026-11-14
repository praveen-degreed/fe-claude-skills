export function getDeepCopy<T>(v: T): T {
  return structuredClone(v);
}
export const safeEncodeURIComponent = (v: string): string => encodeURIComponent(v ?? '');
export function generateGuid(): string {
  return crypto.randomUUID();
}
