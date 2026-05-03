import { useEffect, useRef, useState } from "react";
import "./App.css";
import {
  fetchLanguages,
  fetchQueue,
  fetchStats,
  submitReview,
  undoReview,
  useSession,
  getStoredLanguage,
  setStoredLanguage,
  type Card,
  type CardStateSnapshot,
  type Language,
  type Rating,
  type Stats
} from "./api";
import { FlipCard } from "./Card";

type View = "today" | "stats";

export default function App() {
  const sessionReady = useSession();
  const [languages, setLanguages] = useState<Language[] | null>(null);
  const [currentCode, setCurrentCode] = useState<string>(getStoredLanguage());
  const [view, setView] = useState<View>("today");
  const [menuOpen, setMenuOpen] = useState(false);

  useEffect(() => {
    fetchLanguages()
      .then((langs) => {
        setLanguages(langs);
        if (langs.length && !langs.find((l) => l.code === currentCode)) {
          const fallback = langs[0].code;
          setCurrentCode(fallback);
          setStoredLanguage(fallback);
        }
      })
      .catch(console.error);
  }, []);

  const current = languages?.find((l) => l.code === currentCode);

  const switchLanguage = (code: string) => {
    setCurrentCode(code);
    setStoredLanguage(code);
    setMenuOpen(false);
  };

  const switchView = (v: View) => {
    setView(v);
    setMenuOpen(false);
  };

  return (
    <div className="page">
      <header>
        <div className="brand">
          <h1 className="wordmark">
            <span className="wordmark-lingo">lingo</span>
            <span className="wordmark-sep">_</span>
            <span className="wordmark-chatul">Chatul</span>
          </h1>
          <p className="tagline">
            {current ? `${current.name} through cats` : "Through cats"}
          </p>
        </div>

        <button
          className="avatar-btn"
          aria-label="Open menu"
          onClick={() => setMenuOpen(true)}
        >
          <CatGlyph />
        </button>
      </header>

      {menuOpen && languages && current && (
        <ProfileMenu
          languages={languages}
          currentCode={currentCode}
          currentView={view}
          onClose={() => setMenuOpen(false)}
          onSwitchLanguage={switchLanguage}
          onSwitchView={switchView}
        />
      )}

      {!sessionReady || !current ? (
        <div className="loading">Setting up your session…</div>
      ) : view === "today" ? (
        <ReviewView language={current} key={`today-${current.code}`} />
      ) : (
        <StatsView language={current} key={`stats-${current.code}`} />
      )}
    </div>
  );
}

function CatGlyph() {
  // Minimalist cat silhouette — uses currentColor so it inherits theme
  return (
    <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" aria-hidden>
      <path d="M5.5 4.5 7 9c-1.4 1.2-2 2.7-2 4.5C5 17.5 8 20 12 20s7-2.5 7-6.5c0-1.8-.6-3.3-2-4.5l1.5-4.5L15 6.7c-.9-.4-1.9-.7-3-.7s-2.1.3-3 .7L5.5 4.5Zm4.7 7.6a1 1 0 1 1 0 2 1 1 0 0 1 0-2Zm3.6 0a1 1 0 1 1 0 2 1 1 0 0 1 0-2ZM12 16.5c-1 0-1.8-.5-2-1.2.6.2 1.3.3 2 .3s1.4-.1 2-.3c-.2.7-1 1.2-2 1.2Z"/>
    </svg>
  );
}

function ProfileMenu({
  languages,
  currentCode,
  currentView,
  onClose,
  onSwitchLanguage,
  onSwitchView
}: {
  languages: Language[];
  currentCode: string;
  currentView: View;
  onClose: () => void;
  onSwitchLanguage: (code: string) => void;
  onSwitchView: (v: View) => void;
}) {
  const panelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="menu-overlay" onClick={onClose}>
      <div
        ref={panelRef}
        className="menu-panel"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-label="Profile menu"
      >
        <section className="menu-section menu-account-section">
          <div className="menu-avatar">
            <CatGlyph />
          </div>
          <div>
            <div className="menu-account-name">Anonymous</div>
            <button className="menu-link" disabled>
              Sign in (coming soon)
            </button>
          </div>
        </section>

        <section className="menu-section">
          <div className="menu-section-title">Language</div>
          <ul className="menu-list">
            {languages.map((l) => (
              <li key={l.code}>
                <button
                  className={l.code === currentCode ? "menu-item active" : "menu-item"}
                  onClick={() => onSwitchLanguage(l.code)}
                >
                  <span>{l.name}</span>
                  {l.code === currentCode && <span className="menu-check">✓</span>}
                </button>
              </li>
            ))}
          </ul>
        </section>

        <section className="menu-section">
          <div className="menu-section-title">View</div>
          <ul className="menu-list">
            <li>
              <button
                className={currentView === "today" ? "menu-item active" : "menu-item"}
                onClick={() => onSwitchView("today")}
              >
                <span>Today's review</span>
                {currentView === "today" && <span className="menu-check">✓</span>}
              </button>
            </li>
            <li>
              <button
                className={currentView === "stats" ? "menu-item active" : "menu-item"}
                onClick={() => onSwitchView("stats")}
              >
                <span>Progress &amp; stats</span>
                {currentView === "stats" && <span className="menu-check">✓</span>}
              </button>
            </li>
          </ul>
        </section>

        <button className="menu-close" onClick={onClose}>
          Close
        </button>
      </div>
    </div>
  );
}

function ReviewView({ language }: { language: Language }) {
  const [queue, setQueue] = useState<Card[] | null>(null);
  const [idx, setIdx] = useState(0);
  const [history, setHistory] = useState<
    { cardId: number; rating: Rating; priorState: CardStateSnapshot | null }[]
  >([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchQueue(language.code).then(setQueue).catch((e) => setError(String(e)));
  }, [language.code]);

  if (error) return <div className="error">Couldn't load queue: {error}</div>;
  if (!queue) return <div className="loading">Loading today's queue…</div>;

  if (queue.length === 0) {
    return (
      <div className="empty-state">
        <h2>You're all caught up</h2>
        <p>No {language.name} cards due right now. Come back later or switch languages.</p>
      </div>
    );
  }

  if (idx >= queue.length) {
    const correct = history.filter((h) => h.rating !== "again").length;
    const wrong = history.length - correct;
    return (
      <div className="empty-state">
        <h2>Done for today!</h2>
        <p>
          You reviewed <strong>{queue.length}</strong> {language.name} cards —{" "}
          <span className="stat-right">{correct} correct</span>,{" "}
          <span className="stat-wrong">{wrong} missed</span>.
        </p>
        <button
          className="btn btn-primary"
          onClick={() => {
            setIdx(0);
            setHistory([]);
            fetchQueue(language.code).then(setQueue);
          }}
        >
          Reload queue
        </button>
      </div>
    );
  }

  const card = queue[idx];
  const newCount = queue.filter((c) => c.is_new).length;
  const reviewCount = queue.length - newCount;

  const onAnswer = async (rating: Rating) => {
    try {
      const result = await submitReview(card.id, rating);
      setHistory((h) => [
        ...h,
        { cardId: card.id, rating, priorState: result.prior_state }
      ]);
    } catch (e) {
      console.error(e);
    }
    setIdx((i) => i + 1);
  };

  const onUndo = async () => {
    if (history.length === 0) return;
    const last = history[history.length - 1];
    try {
      await undoReview(last.cardId, last.priorState);
    } catch (e) {
      console.error(e);
    }
    setHistory((h) => h.slice(0, -1));
    setIdx((i) => Math.max(0, i - 1));
  };

  return (
    <div className="review">
      <div className="session-header">
        <span className="session-bit">{newCount} new</span>
        <span className="session-dot">·</span>
        <span className="session-bit">{reviewCount} review</span>
      </div>

      <div className="review-top">
        <div className="progress">
          Card <strong>{idx + 1}</strong> of <strong>{queue.length}</strong>
        </div>
        {history.length > 0 && (
          <button className="undo-btn" onClick={onUndo} aria-label="Undo last review">
            ↶ Undo
          </button>
        )}
      </div>

      <FlipCard card={card} rtl={language.rtl} onAnswer={onAnswer} />
    </div>
  );
}

function StatsView({ language }: { language: Language }) {
  const [stats, setStats] = useState<Stats | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchStats(language.code).then(setStats).catch((e) => setError(String(e)));
  }, [language.code]);

  if (error) return <div className="error">Couldn't load stats: {error}</div>;
  if (!stats) return <div className="loading">Loading stats…</div>;

  const boxes = [1, 2, 3, 4, 5];
  const maxBox = Math.max(1, ...boxes.map((b) => stats.box_distribution[b] || 0));
  const intervals = ["1 day", "2 days", "4 days", "8 days", "16 days"];

  return (
    <div className="stats">
      <div className="stat-row">
        <StatCard
          label="Streak"
          value={stats.streak_days}
          suffix={stats.streak_days === 1 ? "day" : "days"}
          accent
        />
        <StatCard label="Today" value={stats.reviewed_today} suffix="reviewed" />
        <StatCard label="Due now" value={stats.due_now} />
      </div>

      <section className="stats-section">
        <h3>Leitner boxes</h3>
        <p className="stats-hint">
          Cards move up a box when you get them right, back to box 1 when wrong.
          Higher box = longer interval before next review.
        </p>
        <ul className="box-list">
          {boxes.map((b) => {
            const count = stats.box_distribution[b] || 0;
            const pct = maxBox === 0 ? 0 : (count / maxBox) * 100;
            return (
              <li key={b} className="box-row">
                <div className="box-label">
                  <span className="box-num">Box {b}</span>
                  <span className="box-interval">every {intervals[b - 1]}</span>
                </div>
                <div className="box-bar">
                  <div
                    className={`box-fill box-fill-${b}`}
                    style={{ width: `${pct}%` }}
                  />
                </div>
                <div className="box-count">{count}</div>
              </li>
            );
          })}
        </ul>
      </section>

      <section className="stats-section">
        <h3>Deck progress</h3>
        <div className="deck-grid">
          <DeckStat label="Total" value={stats.total_cards} />
          <DeckStat label="Started" value={stats.cards_started} />
          <DeckStat label="Mastered" value={stats.cards_mastered} />
          <DeckStat label="New" value={stats.cards_new} />
        </div>
      </section>
    </div>
  );
}

function StatCard({
  label,
  value,
  suffix,
  accent
}: {
  label: string;
  value: number;
  suffix?: string;
  accent?: boolean;
}) {
  return (
    <div className={accent ? "stat-card stat-card-accent" : "stat-card"}>
      <div className="stat-card-value">{value}</div>
      <div className="stat-card-label">
        {label}
        {suffix ? ` · ${suffix}` : ""}
      </div>
    </div>
  );
}

function DeckStat({ label, value }: { label: string; value: number }) {
  return (
    <div className="deck-stat">
      <div className="deck-stat-value">{value}</div>
      <div className="deck-stat-label">{label}</div>
    </div>
  );
}
