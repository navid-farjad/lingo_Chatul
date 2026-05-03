import { useEffect, useState } from "react";
import "./App.css";
import {
  fetchLanguages,
  fetchQueue,
  fetchStats,
  submitReview,
  useSession,
  getStoredLanguage,
  setStoredLanguage,
  type Card,
  type Language,
  type Stats
} from "./api";
import { FlipCard } from "./Card";

type View = "today" | "stats";

export default function App() {
  const sessionReady = useSession();
  const [languages, setLanguages] = useState<Language[] | null>(null);
  const [currentCode, setCurrentCode] = useState<string>(getStoredLanguage());
  const [view, setView] = useState<View>("today");

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
        {languages && languages.length > 1 && (
          <LanguageSwitch
            languages={languages}
            currentCode={currentCode}
            onChange={switchLanguage}
          />
        )}
        <nav className="tabs">
          <button
            className={view === "today" ? "tab active" : "tab"}
            onClick={() => setView("today")}
          >
            Today
          </button>
          <button
            className={view === "stats" ? "tab active" : "tab"}
            onClick={() => setView("stats")}
          >
            Stats
          </button>
        </nav>
      </header>

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

function LanguageSwitch({
  languages,
  currentCode,
  onChange
}: {
  languages: Language[];
  currentCode: string;
  onChange: (code: string) => void;
}) {
  return (
    <div className="lang-switch">
      {languages.map((l) => (
        <button
          key={l.code}
          className={l.code === currentCode ? "lang-tab active" : "lang-tab"}
          onClick={() => onChange(l.code)}
        >
          {l.name}
        </button>
      ))}
    </div>
  );
}

function ReviewView({ language }: { language: Language }) {
  const [queue, setQueue] = useState<Card[] | null>(null);
  const [idx, setIdx] = useState(0);
  const [stats, setStats] = useState({ right: 0, wrong: 0 });
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
    return (
      <div className="empty-state">
        <h2>Done for today!</h2>
        <p>
          You reviewed <strong>{queue.length}</strong> {language.name} cards —{" "}
          <span className="stat-right">{stats.right} correct</span>,{" "}
          <span className="stat-wrong">{stats.wrong} missed</span>.
        </p>
        <button
          className="btn btn-primary"
          onClick={() => {
            setIdx(0);
            setStats({ right: 0, wrong: 0 });
            fetchQueue(language.code).then(setQueue);
          }}
        >
          Reload queue
        </button>
      </div>
    );
  }

  const card = queue[idx];

  return (
    <div className="review">
      <div className="progress">
        Card <strong>{idx + 1}</strong> of <strong>{queue.length}</strong>
      </div>
      <FlipCard
        card={card}
        rtl={language.rtl}
        onAnswer={async (correct) => {
          setStats((s) => ({
            right: s.right + (correct ? 1 : 0),
            wrong: s.wrong + (correct ? 0 : 1)
          }));
          submitReview(card.id, correct).catch((e) => console.error(e));
          setIdx((i) => i + 1);
        }}
      />
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
