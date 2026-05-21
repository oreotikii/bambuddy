import { describe, it, expect } from 'vitest';
import {
  printerPresetCode,
  presetModelCodes,
  presetCompatibility,
} from '../../utils/slicerPrinterMatch';

describe('printerPresetCode', () => {
  it('maps Bambu stock printer names to model codes', () => {
    expect(printerPresetCode('Bambu Lab X1 Carbon 0.4 nozzle')).toBe('X1C');
    expect(printerPresetCode('Bambu Lab X1E 0.4 nozzle')).toBe('X1E');
    expect(printerPresetCode('Bambu Lab X1 0.4 nozzle')).toBe('X1');
    expect(printerPresetCode('Bambu Lab P1S 0.4 nozzle')).toBe('P1S');
    expect(printerPresetCode('Bambu Lab P1P 0.4 nozzle')).toBe('P1P');
    expect(printerPresetCode('Bambu Lab A1 mini 0.4 nozzle')).toBe('A1M');
    expect(printerPresetCode('Bambu Lab A1 0.4 nozzle')).toBe('A1');
    expect(printerPresetCode('Bambu Lab H2D 0.4 nozzle')).toBe('H2D');
  });

  it('prefers the more specific name when prefixes overlap', () => {
    // "X1 Carbon" must not be read as bare "X1"; "A1 mini" not as "A1".
    expect(printerPresetCode('X1 Carbon')).toBe('X1C');
    expect(printerPresetCode('A1 mini')).toBe('A1M');
  });

  it('returns null for an unrecognised / custom printer', () => {
    expect(printerPresetCode('My Custom Voron 0.4')).toBeNull();
    expect(printerPresetCode('')).toBeNull();
  });
});

describe('presetModelCodes', () => {
  it('parses a single model from the @BBL suffix', () => {
    expect([...presetModelCodes('0.20mm Standard @BBL X1C')]).toEqual(['X1C']);
    expect([...presetModelCodes('Bambu PLA Basic @BBL A1M')]).toEqual(['A1M']);
  });

  it('parses multiple models from one suffix', () => {
    const codes = presetModelCodes('0.20mm Standard @BBL X1C X1');
    expect(codes.has('X1C')).toBe(true);
    expect(codes.has('X1')).toBe(true);
    expect(codes.size).toBe(2);
  });

  it('returns an empty set for generic / untagged presets', () => {
    expect(presetModelCodes('Generic PLA @base').size).toBe(0);
    expect(presetModelCodes('My Custom Process').size).toBe(0);
  });
});

describe('presetCompatibility', () => {
  it('uses compatible_printers exactly when present (local-tier override)', () => {
    const preset = {
      name: 'My Process',
      compatible_printers: ['Bambu Lab X1 Carbon 0.4 nozzle'],
    };
    expect(
      presetCompatibility(preset, 'Bambu Lab X1 Carbon 0.4 nozzle', 'X1C'),
    ).toBe('match');
    expect(presetCompatibility(preset, 'Bambu Lab A1 0.4 nozzle', 'A1')).toBe(
      'mismatch',
    );
  });

  it('falls back to the name heuristic when compatible_printers is absent', () => {
    const preset = { name: '0.20mm Standard @BBL X1C' };
    expect(presetCompatibility(preset, 'Bambu Lab X1 Carbon 0.4 nozzle', 'X1C')).toBe(
      'match',
    );
    expect(presetCompatibility(preset, 'Bambu Lab A1 0.4 nozzle', 'A1')).toBe(
      'mismatch',
    );
  });

  it('is unknown when the preset carries no resolvable model', () => {
    expect(presetCompatibility({ name: 'Generic PLA @base' }, 'Bambu Lab X1 Carbon', 'X1C')).toBe(
      'unknown',
    );
  });

  it('is unknown when the selected printer is unrecognised', () => {
    expect(
      presetCompatibility({ name: '0.20mm Standard @BBL X1C' }, 'My Custom Printer', null),
    ).toBe('unknown');
  });

  it('is unknown when compatible_printers is set but no printer is selected', () => {
    expect(
      presetCompatibility(
        { name: 'P', compatible_printers: ['Bambu Lab X1 Carbon 0.4 nozzle'] },
        null,
        null,
      ),
    ).toBe('unknown');
  });
});
