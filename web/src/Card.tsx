import { useEffect, useRef, useState } from "react";
import type { Card } from "./api";

type Props = {
  card: Card;
  onAnswer: (correct: boolean) => void;
};

export function FlipCard({ card, onAnswer }: Props) {
  const [flipped, setFlipped] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  // Reset to front whenever card changes
  useEffect(() => {
    setFlipped(false);
  }, [card.id]);

  const playAudio = (e?: React.MouseEvent) => {
    e?.stopPropagation();
    audioRef.current?.play().catch(() => {});
  };

  return (
    <div className="card-stage">
      <div
        className={`flip-card ${flipped ? "flipped" : ""}`}
        onClick={() => !flipped && setFlipped(true)}
        role="button"
        tabIndex={0}
      >
        <div className="flip-inner">
          <div className="flip-front">
            <div className="front-content">
              <div className="native-large">{card.native}</div>
              <div className="romanization-large">{card.romanization}</div>
              <button className="audio-btn" onClick={playAudio} aria-label="Play pronunciation">
                ▶ Listen
              </button>
              <div className="flip-hint">Tap to reveal</div>
            </div>
          </div>

          <div className="flip-back">
            <img src={card.image_url} alt={card.english} />
            <div className="back-content">
              <div className="english-large">{card.english}</div>
              <p className="story">{card.story}</p>
            </div>
          </div>
        </div>
        <audio ref={audioRef} src={card.audio_url} preload="auto" />
      </div>

      {flipped && (
        <div className="answer-buttons">
          <button className="btn btn-wrong" onClick={() => onAnswer(false)}>
            ✗ Didn't know
          </button>
          <button className="btn btn-right" onClick={() => onAnswer(true)}>
            ✓ Knew it
          </button>
        </div>
      )}
    </div>
  );
}
