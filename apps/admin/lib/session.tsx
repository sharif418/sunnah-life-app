"use client";

// Session provider — token bootstrap, /api/me hydration, login/logout, role gate.
// The access token lives in localStorage (sl_admin_token) with a rotating
// refresh token (sl_admin_refresh); api.ts refreshes transparently on 401 and
// dispatches SESSION_EXPIRED_EVENT when the family is dead.

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import {
  api,
  getToken,
  getRefreshTokenSafe,
  REFRESH_KEY,
  setTokens,
  SESSION_EXPIRED_EVENT,
  TOKEN_KEY,
  type Role,
  type User,
} from "./api";
import { isSupervisor, isFullAdmin } from "./labels";

export type SessionStatus = "loading" | "authenticated" | "anonymous" | "forbidden";

interface SessionValue {
  status: SessionStatus;
  user: User | null;
  /** supervisor = usrah_head | invigilator | full_admin */
  supervisor: boolean;
  fullAdmin: boolean;
  login: (phone: string, code: string) => Promise<User>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const SessionContext = createContext<SessionValue | null>(null);

export function useSession(): SessionValue {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession must be used inside <SessionProvider>");
  return ctx;
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<SessionStatus>("loading");
  const [user, setUser] = useState<User | null>(null);
  const booted = useRef(false);

  const loadMe = useCallback(async (): Promise<User | null> => {
    const { user: me } = await api.me();
    setUser(me);
    if (!me) {
      setTokens(null, null);
      setStatus("anonymous");
    } else if (!isSupervisor(me.role)) {
      setStatus("forbidden");
    } else {
      setStatus("authenticated");
    }
    return me;
  }, []);

  useEffect(() => {
    if (booted.current) return;
    booted.current = true;
    // Bootstrap off the synchronous effect body (react-hooks lint): the token
    // check + /api/me hydration settle in a microtask right after mount.
    const boot = async () => {
      if (!getToken()) {
        setStatus("anonymous");
        return;
      }
      try {
        await loadMe();
      } catch {
        setTokens(null, null);
        setStatus("anonymous");
      }
    };
    Promise.resolve().then(boot);
  }, [loadMe]);

  useEffect(() => {
    const onExpired = () => {
      setUser(null);
      setStatus("anonymous");
    };
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired);
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired);
  }, []);

  const login = useCallback(
    async (phone: string, code: string): Promise<User> => {
      const res = await api.verifyOtp(phone, code);
      setTokens(res.accessToken, res.refreshToken);
      setUser(res.user);
      if (!isSupervisor(res.user.role)) {
        setStatus("forbidden");
      } else {
        setStatus("authenticated");
      }
      return res.user;
    },
    []
  );

  const logout = useCallback(async () => {
    const refresh = getRefreshTokenSafe();
    await api.logout(refresh);
    setTokens(null, null);
    setUser(null);
    setStatus("anonymous");
  }, []);

  const refreshUser = useCallback(async () => {
    if (!getToken()) return;
    try {
      await loadMe();
    } catch {
      // keep the current state on transient failures
    }
  }, [loadMe]);

  const value = useMemo<SessionValue>(
    () => ({
      status,
      user,
      supervisor: isSupervisor(user?.role),
      fullAdmin: isFullAdmin(user?.role),
      login,
      logout,
      refreshUser,
    }),
    [status, user, login, logout, refreshUser]
  );

  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>;
}

export { TOKEN_KEY, REFRESH_KEY };
export type { Role };
