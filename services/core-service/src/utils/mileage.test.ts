import { convertMileage, isPlausibleMileageUpdate } from './mileage';

describe('convertMileage', () => {
  it('returns the same value when units match', () => {
    expect(convertMileage(100, 'km', 'km')).toBe(100);
  });

  it('converts km to miles', () => {
    expect(convertMileage(100, 'km', 'mi')).toBe(62);
  });

  it('converts miles to km', () => {
    expect(convertMileage(62, 'mi', 'km')).toBe(100);
  });
});

describe('isPlausibleMileageUpdate', () => {
  it('accepts a higher mileage reading', () => {
    expect(isPlausibleMileageUpdate(50000, 50100)).toBe(true);
  });

  it('accepts an equal mileage reading', () => {
    expect(isPlausibleMileageUpdate(50000, 50000)).toBe(true);
  });

  it('rejects a lower mileage reading', () => {
    expect(isPlausibleMileageUpdate(50000, 49000)).toBe(false);
  });
});
