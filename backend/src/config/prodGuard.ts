import { DEV_JWT_SECRET } from '../auth/jwt';

// Sous-ensemble d'env lu par le garde (facilite les tests).
type Env = Record<string, string | undefined>;

export function isProduction(env: Env = process.env): boolean {
  return env.NODE_ENV === 'production';
}

// Fail-fast au démarrage : en production, les valeurs par défaut « dev »
// (secret JWT public, seed admin par défaut, OTP « 0000 ») sont des portes
// dérobées. On refuse de démarrer plutôt que de servir silencieusement dessus.
// Le seed admin de dev, lui, est sauté selon isProduction() côté boot.
export function assertProdSecurity(env: Env = process.env): void {
  if (!isProduction(env)) return;
  const problems: string[] = [];

  if (!env.JWT_SECRET || env.JWT_SECRET === DEV_JWT_SECRET) {
    problems.push('JWT_SECRET manquant ou égal au placeholder de dev (signature forgeable)');
  }
  // Sans ceci, generateOtp() renvoie « 0000 » → toute prise de compte par OTP.
  if (env.SMS_ENABLED !== 'true') {
    problems.push('SMS_ENABLED doit valoir "true" en production (sinon OTP factice « 0000 »)');
  }

  if (problems.length > 0) {
    throw new Error(
      `Configuration de production non sécurisée — démarrage refusé :\n  - ${problems.join('\n  - ')}`,
    );
  }
}
