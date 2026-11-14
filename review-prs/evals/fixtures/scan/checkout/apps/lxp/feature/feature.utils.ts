export function sortByName(items: { name: string }[]) {
  return [...items].sort((a, b) => a.name.localeCompare(b.name));
}
