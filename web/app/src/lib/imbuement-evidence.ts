function numeric(value: unknown): number | null {
  if (value === null || value === undefined || value === "" || typeof value === "boolean") return null;
  const number = typeof value === "number" || typeof value === "string" ? Number(value) : NaN;
  return Number.isFinite(number) && number >= 0 ? number : null;
}
const format = (value: number) => value.toLocaleString("pt-BR", { maximumFractionDigits: 1 });
export function imbuementPotency(value: unknown, unit: unknown): string {
  const number = numeric(value);
  if (number === null) return "Não informado";
  if (unit === "percent") return `${format(number)}%`;
  return `${format(number)}${typeof unit === "string" && unit.trim() ? ` ${unit}` : " · unidade não informada"}`;
}
export function observedDamageShare(value: unknown): string {
  const number = numeric(value);
  return number !== null && number <= 1 ? `${format(number * 100)}%` : "Não informado";
}
export function observedProfileCount(value: unknown): string {
  const number = numeric(value);
  return number !== null && Number.isInteger(number) ? format(number) : "Não informado";
}
