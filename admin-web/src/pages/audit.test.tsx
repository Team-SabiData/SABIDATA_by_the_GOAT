import { describe, expect, it } from 'vitest';
import { csvField } from './Audit';

// Export CSV du journal d'audit : chaque champ doit être quoté/échappé
// (guillemets doublés) et l'injection de formule (=, +, -, @) neutralisée
// par une apostrophe de garde — sinon Excel/Sheets exécute la valeur.
describe('csvField', () => {
  it('entoure toujours de guillemets', () => {
    expect(csvField('simple')).toBe('"simple"');
    expect(csvField('')).toBe('""');
  });

  it('double les guillemets internes', () => {
    expect(csvField('il a dit "stop"')).toBe('"il a dit ""stop"""');
  });

  it('protège le séparateur ; et les retours à la ligne au sein du champ', () => {
    expect(csvField('a;b')).toBe('"a;b"');
    expect(csvField('ligne1\nligne2')).toBe('"ligne1\nligne2"');
  });

  it('neutralise une valeur qui commence par =, +, - ou @ (injection formule)', () => {
    expect(csvField('=cmd|"/bin/sh"!A1')).toBe('"\'=cmd|""/bin/sh""!A1"');
    expect(csvField('+1234')).toBe('"\'+1234"');
    expect(csvField('-1234')).toBe('"\'-1234"');
    expect(csvField('@SUM(A1)')).toBe('"\'@SUM(A1)"');
  });

  it('laisse intact un motif normal ne commençant pas par un caractère dangereux', () => {
    expect(csvField('virement effectué réf 123')).toBe('"virement effectué réf 123"');
  });
});
