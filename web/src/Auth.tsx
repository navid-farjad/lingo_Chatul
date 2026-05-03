import { useState } from "react";
import { signUp, login } from "./api";

export type AuthMode = "signup" | "login";

type Props = {
  mode: AuthMode;
  onClose: () => void;
  onModeChange: (m: AuthMode) => void;
  onSuccess: () => void | Promise<void>;
};

export function AuthModal({ mode, onClose, onModeChange, onSuccess }: Props) {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [passwordConfirm, setPasswordConfirm] = useState("");
  const [name, setName] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    if (mode === "signup" && password !== passwordConfirm) {
      setError("Passwords don't match");
      return;
    }

    setLoading(true);
    try {
      if (mode === "signup") {
        await signUp({
          email: email.trim(),
          password,
          password_confirmation: passwordConfirm,
          name: name.trim() || undefined
        });
      } else {
        await login(email.trim(), password);
      }
      await onSuccess();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="auth-overlay" onClick={onClose}>
      <div
        className="auth-panel"
        onClick={(e) => e.stopPropagation()}
        role="dialog"
        aria-label={mode === "signup" ? "Create account" : "Log in"}
      >
        <div className="auth-tabs">
          <button
            type="button"
            className={mode === "signup" ? "auth-tab active" : "auth-tab"}
            onClick={() => onModeChange("signup")}
          >
            Create account
          </button>
          <button
            type="button"
            className={mode === "login" ? "auth-tab active" : "auth-tab"}
            onClick={() => onModeChange("login")}
          >
            Log in
          </button>
        </div>

        <form className="auth-form" onSubmit={submit}>
          {mode === "signup" && (
            <label className="auth-field">
              <span>Name (optional)</span>
              <input
                type="text"
                value={name}
                onChange={(e) => setName(e.target.value)}
                autoComplete="name"
                placeholder="What should we call you?"
              />
            </label>
          )}

          <label className="auth-field">
            <span>Email</span>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              autoFocus
              autoComplete={mode === "signup" ? "email" : "username"}
            />
          </label>

          <label className="auth-field">
            <span>Password</span>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              minLength={8}
              autoComplete={mode === "signup" ? "new-password" : "current-password"}
            />
          </label>

          {mode === "signup" && (
            <label className="auth-field">
              <span>Confirm password</span>
              <input
                type="password"
                value={passwordConfirm}
                onChange={(e) => setPasswordConfirm(e.target.value)}
                required
                minLength={8}
                autoComplete="new-password"
              />
            </label>
          )}

          {error && <div className="auth-error">{error}</div>}

          <button type="submit" disabled={loading} className="auth-submit">
            {loading
              ? "…"
              : mode === "signup"
                ? "Create account"
                : "Log in"}
          </button>

          {mode === "signup" && (
            <p className="auth-hint">
              Your local progress will be carried over to your new account.
            </p>
          )}
        </form>

        <button type="button" className="auth-cancel" onClick={onClose}>
          Cancel
        </button>
      </div>
    </div>
  );
}
