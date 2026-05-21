// Printer-compatibility matching for the SliceModal's process / filament
// dropdowns (#1325). Bambuddy can't filter every preset tier the same way:
//
//   - local presets carry the slicer's own `compatible_printers` list (a
//     precise list of printer-preset names) — used directly when present.
//   - cloud / standard presets carry no compatibility data, so we fall back
//     to the "@BBL <model>" suffix Bambu Studio / OrcaSlicer embed in preset
//     names (e.g. "0.20mm Standard @BBL X1C").
//
// Either way the result drives grouping, not hard hiding: a preset whose
// compatibility can't be determined stays in the main list, and only a
// preset that resolves to a *different* printer is pushed into an
// "Other printers" group.

// Canonical Bambu Lab model codes exactly as they appear in preset-name
// suffixes. Order is irrelevant here — this is a membership set.
const KNOWN_MODEL_CODES = new Set([
  'X1C',
  'X1E',
  'X1',
  'P1S',
  'P1P',
  'A1M',
  'A1',
  'H2D',
  'H2S',
]);

// Ordered printer-preset-name patterns → model code. First match wins, so
// more specific names ("X1 Carbon", "A1 mini") must precede their prefixes
// ("X1", "A1").
const PRINTER_NAME_PATTERNS: { re: RegExp; code: string }[] = [
  { re: /x1\s*-?\s*carbon/i, code: 'X1C' },
  { re: /\bx1c\b/i, code: 'X1C' },
  { re: /\bx1e\b/i, code: 'X1E' },
  { re: /\bx1\b/i, code: 'X1' },
  { re: /\bp1s\b/i, code: 'P1S' },
  { re: /\bp1p\b/i, code: 'P1P' },
  { re: /a1\s*mini/i, code: 'A1M' },
  { re: /\ba1m\b/i, code: 'A1M' },
  { re: /\ba1\b/i, code: 'A1' },
  { re: /\bh2d\b/i, code: 'H2D' },
  { re: /\bh2s\b/i, code: 'H2S' },
];

/**
 * Derive a Bambu model code from a printer-preset name
 * (e.g. "Bambu Lab X1 Carbon 0.4 nozzle" → "X1C"). Returns null when the
 * name matches no known model — a custom / third-party printer, for which
 * we can't filter and so show every preset.
 */
export function printerPresetCode(name: string): string | null {
  for (const { re, code } of PRINTER_NAME_PATTERNS) {
    if (re.test(name)) return code;
  }
  return null;
}

/**
 * Parse the "@BBL <model>..." suffix of a process / filament preset name into
 * the set of model codes it targets. A preset can list several
 * ("... @BBL X1C X1"); a generic preset ("Generic PLA @base") yields an
 * empty set, meaning "applies everywhere / can't tell".
 */
export function presetModelCodes(name: string): Set<string> {
  const at = name.lastIndexOf('@');
  if (at < 0) return new Set();
  const tokens = name
    .slice(at + 1)
    .toUpperCase()
    .split(/[\s,]+/)
    .filter(Boolean);
  return new Set(tokens.filter((tok) => KNOWN_MODEL_CODES.has(tok)));
}

export type PrinterCompatibility = 'match' | 'mismatch' | 'unknown';

/**
 * Classify a process / filament preset against the selected printer.
 *
 * - 'match'    — the preset is compatible with the selected printer.
 * - 'mismatch' — the preset resolves to a *different* printer.
 * - 'unknown'  — compatibility can't be determined (no data, generic preset,
 *                or an unrecognised printer); the caller should not hide it.
 */
export function presetCompatibility(
  preset: { name: string; compatible_printers?: string[] | null },
  selectedPrinterName: string | null,
  selectedPrinterCode: string | null,
): PrinterCompatibility {
  // Precise link first: the slicer's own compatible_printers list (local tier).
  const compat = preset.compatible_printers;
  if (compat && compat.length > 0) {
    if (!selectedPrinterName) return 'unknown';
    return compat.includes(selectedPrinterName) ? 'match' : 'mismatch';
  }
  // Heuristic fallback: the "@BBL <model>" suffix in the preset name.
  const codes = presetModelCodes(preset.name);
  if (codes.size === 0 || !selectedPrinterCode) return 'unknown';
  return codes.has(selectedPrinterCode) ? 'match' : 'mismatch';
}
