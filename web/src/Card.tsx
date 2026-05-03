import { useEffect, useRef, useState } from "react";
import type { Card, Rating } from "./api";

type Props = {
  card: Card;
  rtl?: boolean;
  onAnswer: (rating: Rating) => void;
};

const RATINGS: { rating: Rating; label: string; sub: string; className: string }[] = [
  { rating: "again", label: "Again", sub: "1 day", className: "btn-again" },
  { rating: "hard",  label: "Hard",  sub: "stay",  className: "btn-hard" },
  { rating: "good",  label: "Good",  sub: "next",  className: "btn-good" },
  { rating: "easy",  label: "Easy",  sub: "skip",  className: "btn-easy" }
];

const SWIPE_THRESHOLD = 120;

export function FlipCard({ card, rtl = false, onAnswer }: Props) {
  const [flipped, setFlipped] = useState(false);
  const [dragX, setDragX] = useState(0);
  const [dragging, setDragging] = useState(false);
  const startX = useRef(0);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    setFlipped(false);
    setDragX(0);
  }, [card.id]);

  const playAudio = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    audioRef.current?.play().catch(() => {});
  };

  const onPointerDown = (e: React.PointerEvent) => {
    if (!flipped) return;
    setDragging(true);
    startX.current = e.clientX;
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragging) return;
    setDragX(e.clientX - startX.current);
  };

  const onPointerUp = (e: React.PointerEvent) => {
    if (!dragging) return;
    setDragging(false);
    const delta = e.clientX - startX.current;
    try { (e.target as HTMLElement).releasePointerCapture(e.pointerId); } catch {}

    if (delta > SWIPE_THRESHOLD) {
      onAnswer("good");
    } else if (delta < -SWIPE_THRESHOLD) {
      onAnswer("again");
    }
    setDragX(0);
  };

  const swipeOpacityLeft = Math.min(1, Math.max(0, -dragX / SWIPE_THRESHOLD));
  const swipeOpacityRight = Math.min(1, Math.max(0, dragX / SWIPE_THRESHOLD));

  return (
    <div className="card-stage">
      <div
        className={`flip-card ${flipped ? "flipped" : ""} ${dragging ? "dragging" : ""}`}
        onClick={() => !flipped && setFlipped(true)}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        style={
          dragX !== 0
            ? {
                transform: `translateX(${dragX}px) rotate(${dragX / 22}deg)`,
                transition: dragging ? "none" : "transform 0.25s cubic-bezier(0.2, 0.8, 0.2, 1)"
              }
            : undefined
        }
      >
        <div className="flip-inner">
          {/* === FRONT === image + word as the cue */}
          <div className="flip-front">
            <div className="card-image-wrap">
              <img src={card.image_url} alt="" draggable={false} />
            </div>
            <div className="card-text-area">
              <div className="card-text-stack">
                <div
                  className="native-large"
                  dir={rtl ? "rtl" : "ltr"}
                  lang={card.language_code}
                >
                  {card.native}
                </div>
                <div className="romanization-large">{card.romanization}</div>
                <button
                  className="audio-btn"
                  onClick={playAudio}
                  aria-label="Play pronunciation"
                >
                  ▶ Listen
                </button>
              </div>
              <div className="flip-hint">Tap card to reveal meaning</div>
            </div>
          </div>

          {/* === BACK === same image + meaning + story */}
          <div className="flip-back">
            <div className="card-image-wrap">
              <img src={card.image_url} alt={card.english} draggable={false} />
            </div>
            <div className="back-content">
              <div className="back-header">
                <div
                  className="back-native"
                  dir={rtl ? "rtl" : "ltr"}
                  lang={card.language_code}
                >
                  {card.native}
                </div>
                <div className="back-romanization">{card.romanization}</div>
              </div>
              <div className="english-row">
                <div className="english-large">{card.english}</div>
                <button
                  className="audio-btn-icon"
                  onClick={playAudio}
                  aria-label="Play pronunciation"
                >
                  ▶
                </button>
              </div>
              <p className="story">{card.story}</p>
            </div>
          </div>
        </div>

        {/* Swipe overlays — visible during drag */}
        {flipped && (
          <>
            <div
              className="swipe-overlay swipe-overlay-left"
              style={{ opacity: swipeOpacityLeft }}
            >
              ✗ Again
            </div>
            <div
              className="swipe-overlay swipe-overlay-right"
              style={{ opacity: swipeOpacityRight }}
            >
              ✓ Got it
            </div>
          </>
        )}

        <audio ref={audioRef} src={card.audio_url} preload="auto" />
      </div>

      {flipped && (
        <>
          <div className="swipe-hint-text">Swipe ← Again · Got it →</div>
          <div className="answer-buttons">
            {RATINGS.map((r) => (
              <button
                key={r.rating}
                className={`btn ${r.className}`}
                onClick={() => onAnswer(r.rating)}
              >
                <span className="btn-label">{r.label}</span>
                <span className="btn-sub">{r.sub}</span>
              </button>
            ))}
          </div>
        </>
      )}
    </div>
  );
}
