import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminApi, setToken, getToken, onUnauthorized } from './api';

describe('client api', () => {
  beforeEach(() => {
    sessionStorage.clear();
    vi.restoreAllMocks();
  });

  it('persiste le token en sessionStorage', () => {
    setToken('abc');
    expect(getToken()).toBe('abc');
    expect(sessionStorage.getItem('sabidata.admin.token')).toBe('abc');
    setToken(null);
    expect(sessionStorage.getItem('sabidata.admin.token')).toBeNull();
  });

  it('401 purge le token et notifie', async () => {
    setToken('abc');
    const cb = vi.fn();
    onUnauthorized(cb);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: { message: 'token invalide' } }), { status: 401 }),
    ));
    await expect(adminApi.users()).rejects.toThrow();
    expect(cb).toHaveBeenCalled();
    expect(getToken()).toBeNull();
  });

  it('fetchClipAudio en 401 purge le token et notifie', async () => {
    setToken('abc');
    const cb = vi.fn();
    onUnauthorized(cb);
    const fetchMock = vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: { message: 'token invalide' } }), { status: 401 }),
    );
    vi.stubGlobal('fetch', fetchMock);
    await expect(adminApi.fetchClipAudio('c1')).rejects.toThrow('Audio indisponible (401)');
    expect(fetchMock.mock.calls[0][0]).toBe('/admin/clips/c1/audio');
    expect(cb).toHaveBeenCalled();
    expect(getToken()).toBeNull();
    expect(sessionStorage.getItem('sabidata.admin.token')).toBeNull();
  });

  it('setUserStatus envoie status + reason en PATCH', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'u1', status: 'banned' }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    await adminApi.setUserStatus('u1', 'banned', 'fraude');
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('/admin/users/u1');
    expect(init.method).toBe('PATCH');
    expect(JSON.parse(init.body)).toEqual({ status: 'banned', reason: 'fraude' });
  });
});
