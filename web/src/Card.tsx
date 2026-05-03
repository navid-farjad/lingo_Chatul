import { useEffect, useRef, useState } from "react";
import type { Card } from "./api";

type Props = {
  card: Card;
  onAnswer: (correct: boolean) => void;
};

export function FlipCard({ card, onAnswer }: Props) {
  const [flipped, setFlipped] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);

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
      >
        <div className="flip-inner">
          {/* === FRONT === image + word as the cue */}
          <div className="flip-front">
            <div className="card-image-wrap">
              <img src={card.image_url} alt="" />
            </div>
            <div className="card-text-area">
              <div className="card-text-stack">
                <div className="native-large">{card.native}</div>
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
              <img src={card.image_url} alt={card.english} />
            </div>
            <div className="back-content">
              <div className="back-header">
                <div className="back-native">{card.native}</div>
                <div className="back-romanization">{card.romanization}</div>
              </div>
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
            <span className="btn-icon">✗</span>
            <span>Again</span>
          </button>
          <button className="btn btn-right" onClick={() => onAnswer(true)}>
            <span className="btn-icon">✓</span>
            <span>Got it</span>
          </button>
        </div>
      )}
    </div>
  );
}
