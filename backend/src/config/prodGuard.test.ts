import { test } from 'node:test';
import assert from 'node:assert/strict';
import { assertProdSecurity, isProduction } from './prodGuard';

const okProd = {
  NODE_ENV: 'production',
  JWT_SECRET: 'a-real-long-random-secret',
  SMS_ENABLED: 'true',
};

test('isProduction — vrai seulement si NODE_ENV=production', () => {
  assert.equal(isProduction({ NODE_ENV: 'production' }), true);
  assert.equal(isProduction({ NODE_ENV: 'development' }), false);
  assert.equal(isProduction({}), false);
});

test('assertProdSecurity — ne lève pas hors production même si tout manque', () => {
  assert.doesNotThrow(() => assertProdSecurity({ NODE_ENV: 'development' }));
  assert.doesNotThrow(() => assertProdSecurity({})); // NODE_ENV absent = pas prod
});

test('assertProdSecurity — config prod complète : ne lève pas', () => {
  assert.doesNotThrow(() => assertProdSecurity(okProd));
});

test('assertProdSecurity — prod sans JWT_SECRET : lève', () => {
  assert.throws(
    () => assertProdSecurity({ ...okProd, JWT_SECRET: undefined }),
    /JWT_SECRET/,
  );
});

test('assertProdSecurity — prod avec JWT_SECRET placeholder : lève', () => {
  assert.throws(
    () => assertProdSecurity({ ...okProd, JWT_SECRET: 'dev-secret-change-me' }),
    /JWT_SECRET/,
  );
});

test('assertProdSecurity — prod sans SMS_ENABLED=true : lève', () => {
  assert.throws(() => assertProdSecurity({ ...okProd, SMS_ENABLED: 'false' }), /SMS_ENABLED/);
  assert.throws(() => assertProdSecurity({ ...okProd, SMS_ENABLED: undefined }), /SMS_ENABLED/);
});

test('assertProdSecurity — agrège tous les problèmes dans le message', () => {
  try {
    assertProdSecurity({ NODE_ENV: 'production' });
    assert.fail('aurait dû lever');
  } catch (e) {
    const msg = (e as Error).message;
    assert.match(msg, /JWT_SECRET/);
    assert.match(msg, /SMS_ENABLED/);
  }
});
