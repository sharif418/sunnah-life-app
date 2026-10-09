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
import { canEditContent, canReviewContent, isSupervisor, isFullAdmin } from "./labels";

export type SessionStatus = "loading" | "authenticated" | "anonymous" | "forbidden";

interface SessionValue {
  status: SessionStatus;
  user: User | null;
  /** supervisor = usrah_head | invigilator | full_admin */
  supervisor: boolean;
  fullAdmin: boolean;
  /** content team (or full_admin): may open the content workflow */
  contentEditor: boolean;
  /** reviewer alim (or full_admin): may approve / reject / roll back */
  contentReviewer: boolean;
  /** on the content team only — sees just the content pages */
  contentOnly: boolean;
  login: (phone: string, code: string) => Promise<User>;
  logout: () => Promise<void>;
  refreshUser: () => Promise<void>;
}

const SessionContext = createContext<SessionValue | null>(null);

/** Who may use the panel: supervisors, and the content team (editors and
 * reviewing scholars, whatever their tarbiyah role — they see only the
 * content pages). */
function admitted(u: User): boolean {
  return isSupervisor(u.role) || canEditContent(u);
}

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
    } else if (!admitted(me)) {
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
      if (!admitted(res.user)) {
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
      contentEditor: canEditContent(user),
      contentReviewer: canReviewContent(user),
      contentOnly: !!user && !isSupervisor(user.role) && canEditContent(user),
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
