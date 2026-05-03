import { useEffect, useState } from "react";

export const API_BASE = "http://localhost:3000";

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
};

export type Session = {
  user_id: number;
  device_token: string;
  tier: string;
};

const TOKEN_KEY = "lingo_chatul_device_token";

async function api<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = localStorage.getItem(TOKEN_KEY);
  const headers = new Headers(init.headers);
  if (token) headers.set("X-Device-Token", token);
  if (init.body) headers.set("Content-Type", "application/json");

  const r = await fetch(`${API_BASE}${path}`, { ...init, headers });
  if (!r.ok) throw new Error(`API ${r.status}: ${await r.text()}`);
  return r.json();
}

export async function createSession(): Promise<Session> {
  const s = await api<Session>("/api/v1/sessions", { method: "POST" });
  localStorage.setItem(TOKEN_KEY, s.device_token);
  return s;
}

export const fetchCards = () => api<Card[]>("/api/v1/cards");
export const fetchQueue = () => api<Card[]>("/api/v1/cards/queue");

export type ReviewResult = {
  card_id: number;
  leitner_box: number;
  next_review_at: string | null;
  correct_count: number;
  incorrect_count: number;
};

export const submitReview = (cardId: number, correct: boolean) =>
  api<ReviewResult>(`/api/v1/cards/${cardId}/reviews`, {
    method: "POST",
    body: JSON.stringify({ correct })
  });

// React hook: ensure a device-token session exists
export function useSession() {
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const existing = localStorage.getItem(TOKEN_KEY);
    if (existing) {
      setReady(true);
    } else {
      createSession()
        .then(() => setReady(true))
        .catch((e) => console.error("Failed to create session:", e));
    }
  }, []);

  return ready;
}
