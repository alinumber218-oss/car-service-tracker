/**
 * Converts a mileage value between km and miles.
 */
export function convertMileage(value: number, from: 'km' | 'mi', to: 'km' | 'mi'): number {
  if (from === to) return value;
  return from === 'km' ? Math.round(value * 0.621371) : Math.round(value / 0.621371);
}

/**
 * Returns true if a new odometer reading is plausible given the last known
 * mileage - i.e. it hasn't decreased (ignoring odometer rollovers, which are
 * rare enough in a modern car to treat as a data-entry error at MVP stage).
 */
export function isPlausibleMileageUpdate(previousMileage: number, newMileage: number): boolean {
  return newMileage >= previousMileage;
}
