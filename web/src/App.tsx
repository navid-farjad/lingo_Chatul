import { useEffect, useState } from "react";
import "./App.css";
import { fetchCards, fetchQueue, submitReview, useSession, type Card } from "./api";
import { FlipCard } from "./Card";

type View = "review" | "gallery";

export default function App() {
  const sessionReady = useSession();
  const [view, setView] = useState<View>("review");

  return (
    <div className="page">
      <header>
        <div className="brand">
          <h1>lingo_Chatul</h1>
          <p className="tagline">Greek through cats</p>
        </div>
        <nav className="tabs">
          <button
            className={view === "review" ? "tab active" : "tab"}
            onClick={() => setView("review")}
          >
            Review
          </button>
          <button
            className={view === "gallery" ? "tab active" : "tab"}
            onClick={() => setView("gallery")}
          >
            Gallery
          </button>
        </nav>
      </header>

      {!sessionReady ? (
        <div className="loading">Setting up your session…</div>
      ) : view === "review" ? (
        <ReviewView />
      ) : (
        <GalleryView />
      )}
    </div>
  );
}

function ReviewView() {
  const [queue, setQueue] = useState<Card[] | null>(null);
  const [idx, setIdx] = useState(0);
  const [stats, setStats] = useState({ right: 0, wrong: 0 });
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchQueue().then(setQueue).catch((e) => setError(String(e)));
  }, []);

  if (error) return <div className="error">Couldn't load queue: {error}</div>;
  if (!queue) return <div className="loading">Loading today's queue…</div>;
  if (queue.length === 0) {
    return (
      <div className="empty-state">
        <h2>No cards yet</h2>
        <p>Run the content pipeline to generate the starter deck.</p>
      </div>
    );
  }

  if (idx >= queue.length) {
    return (
      <div className="empty-state">
        <h2>Done for today! 🎉</h2>
        <p>
          You reviewed <strong>{queue.length}</strong> cards —
          {" "}<span className="stat-right">{stats.right} correct</span>,
          {" "}<span className="stat-wrong">{stats.wrong} missed</span>.
        </p>
        <button
          className="btn btn-primary"
          onClick={() => {
            setIdx(0);
            setStats({ right: 0, wrong: 0 });
            fetchQueue().then(setQueue);
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

function GalleryView() {
  const [cards, setCards] = useState<Card[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    fetchCards().then(setCards).catch((e) => setError(String(e)));
  }, []);

  if (error) return <div className="error">Couldn't load cards: {error}</div>;
  if (!cards) return <div className="loading">Loading cards…</div>;
  if (cards.length === 0) {
    return <div className="empty-state"><h2>No cards yet</h2></div>;
  }

  return (
    <div className="grid">
      {cards.map((c) => (
        <article key={c.id} className="gallery-card">
          <img src={c.image_url} alt={c.english} loading="lazy" />
          <div className="gallery-card-body">
            <h3 className="native">{c.native}</h3>
            <div className="romanization">{c.romanization}</div>
            <div className="english">{c.english}</div>
            <p className="story-small">{c.story}</p>
            <audio controls src={c.audio_url} preload="none" />
          </div>
        </article>
      ))}
    </div>
  );
}
