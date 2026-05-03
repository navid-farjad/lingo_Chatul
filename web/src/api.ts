import { useEffect, useState } from "react";

export const API_BASE = import.meta.env.VITE_API_BASE ?? "http://localhost:3000";

export type Card = {
  id: number;
  native: string;
  romanization: string;
  english: string;
  part_of_speech: string;
  language_code: string;
  language_name: string;
  story: string;
  image_url: string;
  audio_url: string;
  is_new?: boolean;
};

export type Language = {
  code: string;
  name: string;
  rtl: boolean;
  card_count: number;
};

export type Session = {
  user_id: number;
  device_token: string;
  email?: string | null;
  name?: string | null;
  tier: string;
};

export type Me = {
  user_id: number;
  device_token: string;
  email: string | null;
  name: string | null;
  tier: string;
  anonymous: boolean;
};

const TOKEN_KEY = "lingo_chatul_device_token";
const LANG_KEY = "lingo_chatul_language";

async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem(TOKEN_KEY);
  const headers = new Headers(init.headers);
  if (token) headers.set("X-Device-Token", token);
  if (init.body) headers.set("Content-Type", "application/json");

  const r = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (!r.ok) {
    let msg = `API ${r.status}`;
    try {
      const body = await r.json();
      if (body.error) msg = body.error;
      else if (Array.isArray(body.errors) && body.errors.length) msg = body.errors.join(". ");
    } catch {
      // body wasn't JSON, keep generic message
    }
    throw new Error(msg);
  }
  return r.json();
}

export async function createSession(): Promise<Session> {
  const s = await api<Session>("/api/v1/sessions", { method: "POST" });
  localStorage.setItem(TOKEN_KEY, s.device_token);
  return s;
}

export const fetchMe = () => api<Me>("/api/v1/me");

export async function signUp(payload: {
  email: string;
  password: string;
  password_confirmation: string;
  name?: string;
}): Promise<Me> {
  const s = await api<Session>("/api/v1/users", {
    method: "POST",
    body: JSON.stringify(payload)
  });
  localStorage.setItem(TOKEN_KEY, s.device_token);
  return await fetchMe();
}

export async function login(email: string, password: string): Promise<Me> {
  const s = await api<Session>("/api/v1/sessions/login", {
    method: "POST",
    body: JSON.stringify({ email, password })
  });
  localStorage.setItem(TOKEN_KEY, s.device_token);
  return await fetchMe();
}

export function logout() {
  localStorage.removeItem(TOKEN_KEY);
}

export const fetchLanguages = () => api<Language[]>("/api/v1/languages");
export const fetchQueue = (languageCode: string) =>
  api<Card[]>(`/api/v1/cards/queue?language=${encodeURIComponent(languageCode)}`);

export type Stats = {
  language: { code: string; name: string; rtl: boolean };
  box_distribution: Record<string, number>;
  total_cards: number;
  cards_started: number;
  cards_new: number;
  cards_mastered: number;
  due_now: number;
  reviewed_today: number;
  streak_days: number;
};

export const fetchStats = (languageCode: string) =>
  api<Stats>(`/api/v1/stats?language=${encodeURIComponent(languageCode)}`);

export type Rating = "again" | "hard" | "good" | "easy";

export type CardStateSnapshot = {
  leitner_box: number;
  correct_count: number;
  incorrect_count: number;
  next_review_at: string | null;
  last_reviewed_at: string | null;
};

export type ReviewResult = {
  card_id: number;
  leitner_box: number;
  next_review_at: string | null;
  correct_count: number;
  incorrect_count: number;
  prior_state: CardStateSnapshot | null;
};

export const submitReview = (cardId: number, rating: Rating) =>
  api<ReviewResult>(`/api/v1/cards/${cardId}/reviews`, {
    method: "POST",
    body: JSON.stringify({ rating })
  });

export const undoReview = (cardId: number, priorState: CardStateSnapshot | null) =>
  api<{ ok: boolean }>(`/api/v1/cards/${cardId}/reviews/undo`, {
    method: "POST",
    body: JSON.stringify({ prior_state: priorState })
  });

// Ensures a device-token session exists and returns the current Me object.
// Components call `refresh` after sign-up / login / logout to re-pull state.
export function useUser() {
  const [user, setUser] = useState<Me | null>(null);
  const [ready, setReady] = useState(false);

  const refresh = async () => {
    try {
      if (!localStorage.getItem(TOKEN_KEY)) {
        await createSession();
      }
      const me = await fetchMe();
      setUser(me);
    } catch (e) {
      console.error("Failed to load user", e);
      // Reset and try once more with a fresh anonymous session
      logout();
      try {
        await createSession();
        const me = await fetchMe();
        setUser(me);
      } catch {
        // give up — UI shows error state
      }
    } finally {
      setReady(true);
    }
  };

  useEffect(() => {
    refresh();
  }, []);

  return { user, ready, refresh };
}

// Backwards-compat wrapper for components that only need readiness
export function useSession() {
  const { ready } = useUser();
  return ready;
}

// Persist current language code in localStorage
export function getStoredLanguage(): string {
  return localStorage.getItem(LANG_KEY) || "el";
}

export function setStoredLanguage(code: string) {
  localStorage.setItem(LANG_KEY, code);
}
