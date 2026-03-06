import { useState, useEffect } from "react";

const screens = ["splash", "phone", "verify", "create-name", "create-date", "create-cadence", "invite", "confirmation"];

const CADENCES = [
  { id: "weekly", label: "Weekly", sub: "Every 7 days" },
  { id: "biweekly", label: "Every 2 weeks", sub: "Bi-weekly" },
  { id: "monthly", label: "Monthly", sub: "Once a month" },
  { id: "once", label: "Just once", sub: "One-time event" },
];

const PRESETS = ["Drinks", "Dinner", "Game night", "Gym", "Hike", "Movie night", "Coffee"];

const QUICK_DATES = [
  { label: "This Friday", days: (5 - new Date().getDay() + 7) % 7 || 7 },
  { label: "This Saturday", days: (6 - new Date().getDay() + 7) % 7 || 7 },
  { label: "Next Sunday", days: (7 - new Date().getDay() + 7) % 7 + 7 },
];

function addDays(d, n) {
  const r = new Date(d);
  r.setDate(r.getDate() + n);
  return r.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

const today = new Date();

export default function StillOnOnboarding() {
  const [screen, setScreen] = useState("splash");
  const [phone, setPhone] = useState("");
  const [code, setCode] = useState(["", "", "", "", "", ""]);
  const [hangoutName, setHangoutName] = useState("");
  const [customName, setCustomName] = useState("");
  const [selectedDate, setSelectedDate] = useState(null);
  const [cadence, setCadence] = useState(null);
  const [animating, setAnimating] = useState(false);
  const [progress, setProgress] = useState(0);

  const workingSteps = ["create-name", "create-date", "create-cadence", "invite"];
  const stepIndex = workingSteps.indexOf(screen);

  const go = (next) => {
    setAnimating(true);
    setTimeout(() => {
      setScreen(next);
      setAnimating(false);
    }, 220);
  };

  useEffect(() => {
    if (screen === "splash") {
      const t = setTimeout(() => go("phone"), 1800);
      return () => clearTimeout(t);
    }
  }, [screen]);

  useEffect(() => {
    const pct = stepIndex >= 0 ? ((stepIndex + 1) / workingSteps.length) * 100 : 0;
    setProgress(pct);
  }, [screen]);

  const formatPhone = (v) => {
    const d = v.replace(/\D/g, "").slice(0, 10);
    if (d.length <= 3) return d;
    if (d.length <= 6) return `(${d.slice(0, 3)}) ${d.slice(3)}`;
    return `(${d.slice(0, 3)}) ${d.slice(3, 6)}-${d.slice(6)}`;
  };

  const handleCode = (i, val) => {
    const next = [...code];
    next[i] = val.replace(/\D/g, "").slice(0, 1);
    setCode(next);
    if (val && i < 5) document.getElementById(`code-${i + 1}`)?.focus();
    if (next.every(Boolean)) setTimeout(() => go("create-name"), 300);
  };

  const finalName = hangoutName === "Custom" ? customName : hangoutName;

  return (
    <div style={{
      minHeight: "100vh",
      background: "#0d0d0d",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontFamily: "'Georgia', serif",
      padding: "0",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=Playfair+Display:ital,wght@0,500;0,700;1,400&family=DM+Sans:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body { background: #0d0d0d; }
        .screen { animation: fadeUp 0.3s ease both; }
        @keyframes fadeUp { from { opacity: 0; transform: translateY(14px); } to { opacity: 1; transform: translateY(0); } }
        .out { animation: fadeOut 0.2s ease both; }
        @keyframes fadeOut { to { opacity: 0; transform: translateY(-10px); } }
        .pill-btn {
          background: #e8d5b0;
          color: #0d0d0d;
          border: none;
          border-radius: 100px;
          padding: 16px 40px;
          font-family: 'DM Sans', sans-serif;
          font-size: 15px;
          font-weight: 500;
          cursor: pointer;
          letter-spacing: 0.02em;
          transition: all 0.15s ease;
          width: 100%;
        }
        .pill-btn:hover { background: #f5e8cc; transform: translateY(-1px); }
        .pill-btn:disabled { background: #2a2a2a; color: #555; cursor: not-allowed; transform: none; }
        .ghost-btn {
          background: transparent;
          color: #888;
          border: 1px solid #2a2a2a;
          border-radius: 100px;
          padding: 14px 28px;
          font-family: 'DM Sans', sans-serif;
          font-size: 14px;
          cursor: pointer;
          transition: all 0.15s;
        }
        .ghost-btn:hover { border-color: #555; color: #ccc; }
        .chip {
          background: #1a1a1a;
          border: 1px solid #2a2a2a;
          color: #ccc;
          border-radius: 100px;
          padding: 12px 22px;
          font-family: 'DM Sans', sans-serif;
          font-size: 14px;
          cursor: pointer;
          transition: all 0.15s ease;
          white-space: nowrap;
        }
        .chip:hover { border-color: #e8d5b0; color: #e8d5b0; }
        .chip.active { background: #e8d5b0; color: #0d0d0d; border-color: #e8d5b0; font-weight: 500; }
        .card-option {
          background: #141414;
          border: 1px solid #252525;
          border-radius: 16px;
          padding: 18px 22px;
          cursor: pointer;
          transition: all 0.15s ease;
          display: flex;
          align-items: center;
          gap: 14px;
        }
        .card-option:hover { border-color: #e8d5b0; }
        .card-option.active { border-color: #e8d5b0; background: #1c1a14; }
        .phone-input {
          background: #141414;
          border: 1px solid #2a2a2a;
          border-radius: 14px;
          padding: 18px 20px;
          color: #fff;
          font-family: 'DM Sans', sans-serif;
          font-size: 22px;
          letter-spacing: 0.05em;
          width: 100%;
          outline: none;
          transition: border-color 0.15s;
          text-align: center;
        }
        .phone-input:focus { border-color: #e8d5b0; }
        .code-box {
          width: 44px; height: 56px;
          background: #141414;
          border: 1px solid #2a2a2a;
          border-radius: 12px;
          color: #fff;
          font-size: 22px;
          text-align: center;
          font-family: 'DM Sans', sans-serif;
          outline: none;
          transition: border-color 0.15s;
        }
        .code-box:focus { border-color: #e8d5b0; }
        .text-input {
          background: #141414;
          border: 1px solid #2a2a2a;
          border-radius: 14px;
          padding: 18px 20px;
          color: #fff;
          font-family: 'DM Sans', sans-serif;
          font-size: 18px;
          width: 100%;
          outline: none;
          transition: border-color 0.15s;
        }
        .text-input:focus { border-color: #e8d5b0; }
        .progress-bar {
          height: 2px;
          background: #1a1a1a;
          border-radius: 2px;
          overflow: hidden;
          margin-bottom: 36px;
        }
        .progress-fill {
          height: 100%;
          background: #e8d5b0;
          border-radius: 2px;
          transition: width 0.4s ease;
        }
        .ember { 
          display: inline-block;
          width: 10px; height: 10px;
          background: #e8d5b0;
          border-radius: 50%;
          box-shadow: 0 0 14px #e8a030, 0 0 28px #e87010;
          animation: pulse 2s ease-in-out infinite;
        }
        @keyframes pulse { 0%,100% { opacity:1; box-shadow: 0 0 14px #e8a030, 0 0 28px #e87010; } 50% { opacity:0.7; box-shadow: 0 0 8px #e8a030, 0 0 16px #e87010; } }
        .invite-link {
          background: #141414;
          border: 1px solid #2a2a2a;
          border-radius: 14px;
          padding: 14px 18px;
          display: flex;
          align-items: center;
          justify-content: space-between;
          gap: 12px;
        }
        .copy-btn {
          background: #e8d5b0;
          color: #0d0d0d;
          border: none;
          border-radius: 8px;
          padding: 8px 16px;
          font-family: 'DM Sans', sans-serif;
          font-size: 13px;
          font-weight: 500;
          cursor: pointer;
          white-space: nowrap;
          flex-shrink: 0;
        }
        .back-btn {
          background: none; border: none; color: #555; cursor: pointer;
          font-family: 'DM Sans', sans-serif; font-size: 13px;
          display: flex; align-items: center; gap: 6px;
          padding: 0; margin-bottom: 24px;
          transition: color 0.15s;
        }
        .back-btn:hover { color: #999; }
        .label { font-family: 'DM Sans', sans-serif; font-size: 12px; color: #555; letter-spacing: 0.1em; text-transform: uppercase; margin-bottom: 10px; }
        .headline { font-family: 'Playfair Display', serif; font-size: 28px; color: #f0e8d8; line-height: 1.25; margin-bottom: 8px; }
        .sub { font-family: 'DM Sans', sans-serif; font-size: 15px; color: #666; line-height: 1.6; margin-bottom: 32px; }
        .annotation {
          font-family: 'Playfair Display', serif;
          font-style: italic;
          font-size: 12px;
          color: #555;
          margin-top: 8px;
          text-align: center;
        }
      `}</style>

      <div style={{
        width: "100%", maxWidth: 420,
        padding: "28px 28px 40px",
        position: "relative",
      }}>

        {/* SPLASH */}
        {screen === "splash" && (
          <div className="screen" style={{ textAlign: "center", padding: "60px 0" }}>
            <div style={{ marginBottom: 24 }}>
              <span className="ember" />
            </div>
            <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 32, color: "#f0e8d8", letterSpacing: "-0.01em" }}>
              StillOn
            </div>
            <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: "#555", marginTop: 8 }}>
              keep the plans alive
            </div>
          </div>
        )}

        {/* PHONE */}
        {screen === "phone" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <div style={{ marginBottom: 40, display: "flex", alignItems: "center", gap: 10 }}>
              <span className="ember" style={{ width: 8, height: 8 }} />
              <span style={{ fontFamily: "'Playfair Display', serif", fontSize: 18, color: "#f0e8d8" }}>StillOn</span>
            </div>
            <p className="label">Get started</p>
            <h1 className="headline">What's your number?</h1>
            <p className="sub">We'll send a quick code. No spam — just your hangout reminders.</p>
            <input
              className="phone-input"
              type="tel"
              placeholder="(555) 000-0000"
              value={phone}
              onChange={e => setPhone(formatPhone(e.target.value))}
              autoFocus
            />
            <p className="annotation">No password needed</p>
            <div style={{ marginTop: 24 }}>
              <button
                className="pill-btn"
                disabled={phone.replace(/\D/g, "").length < 10}
                onClick={() => go("verify")}
              >
                Send code →
              </button>
            </div>
          </div>
        )}

        {/* VERIFY */}
        {screen === "verify" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <button className="back-btn" onClick={() => go("phone")}>← back</button>
            <p className="label">Verification</p>
            <h1 className="headline">Check your texts</h1>
            <p className="sub">Sent to {phone}</p>
            <div style={{ display: "flex", gap: 8, justifyContent: "center", marginBottom: 28 }}>
              {code.map((v, i) => (
                <input
                  key={i}
                  id={`code-${i}`}
                  className="code-box"
                  value={v}
                  onChange={e => handleCode(i, e.target.value)}
                  onKeyDown={e => {
                    if (e.key === "Backspace" && !v && i > 0) document.getElementById(`code-${i - 1}`)?.focus();
                  }}
                  maxLength={1}
                  autoFocus={i === 0}
                />
              ))}
            </div>
            <button className="ghost-btn" style={{ width: "100%" }}>Resend code</button>
          </div>
        )}

        {/* STEPS — progress bar */}
        {stepIndex >= 0 && screen !== "confirmation" && (
          <div className="progress-bar">
            <div className="progress-fill" style={{ width: `${progress}%` }} />
          </div>
        )}

        {/* STEP 1 — Name */}
        {screen === "create-name" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <p className="label">Step 1 of 4 · Name it</p>
            <h1 className="headline">What's the hangout?</h1>
            <p className="sub">Pick a vibe or name it yourself.</p>
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 20 }}>
              {PRESETS.map(p => (
                <button
                  key={p}
                  className={`chip ${hangoutName === p ? "active" : ""}`}
                  onClick={() => { setHangoutName(p); setCustomName(""); }}
                >{p}</button>
              ))}
              <button
                className={`chip ${hangoutName === "Custom" ? "active" : ""}`}
                onClick={() => setHangoutName("Custom")}
              >Custom…</button>
            </div>
            {hangoutName === "Custom" && (
              <input
                className="text-input"
                placeholder="Name your hangout"
                value={customName}
                onChange={e => setCustomName(e.target.value)}
                autoFocus
                style={{ marginBottom: 20 }}
              />
            )}
            <button
              className="pill-btn"
              disabled={!finalName}
              onClick={() => go("create-date")}
            >Next →</button>
          </div>
        )}

        {/* STEP 2 — Date */}
        {screen === "create-date" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <button className="back-btn" onClick={() => go("create-name")}>← back</button>
            <p className="label">Step 2 of 4 · When</p>
            <h1 className="headline">First one's when?</h1>
            <p className="sub">You can always adjust later.</p>
            <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 20 }}>
              {QUICK_DATES.map(d => (
                <button
                  key={d.label}
                  className={`card-option ${selectedDate === d.label ? "active" : ""}`}
                  onClick={() => setSelectedDate(d.label)}
                >
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: "#e8d5b0", fontWeight: 500 }}>{d.label}</div>
                    <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#555", marginTop: 2 }}>{addDays(today, d.days)}</div>
                  </div>
                  {selectedDate === d.label && <span style={{ color: "#e8d5b0" }}>✓</span>}
                </button>
              ))}
              <button
                className={`card-option ${selectedDate === "pick" ? "active" : ""}`}
                onClick={() => setSelectedDate("pick")}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: "#e8d5b0", fontWeight: 500 }}>Pick a date…</div>
                  <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#555", marginTop: 2 }}>Choose from calendar</div>
                </div>
                {selectedDate === "pick" && <span style={{ color: "#e8d5b0" }}>✓</span>}
              </button>
            </div>
            <button
              className="pill-btn"
              disabled={!selectedDate}
              onClick={() => go("create-cadence")}
            >Next →</button>
          </div>
        )}

        {/* STEP 3 — Cadence */}
        {screen === "create-cadence" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <button className="back-btn" onClick={() => go("create-date")}>← back</button>
            <p className="label">Step 3 of 4 · Cadence</p>
            <h1 className="headline">How often?</h1>
            <p className="sub">StillOn will ping everyone before each one.</p>
            <div style={{ display: "flex", flexDirection: "column", gap: 10, marginBottom: 24 }}>
              {CADENCES.map(c => (
                <button
                  key={c.id}
                  className={`card-option ${cadence === c.id ? "active" : ""}`}
                  onClick={() => setCadence(c.id)}
                >
                  <div style={{ flex: 1 }}>
                    <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: "#e8d5b0", fontWeight: 500 }}>{c.label}</div>
                    <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#555", marginTop: 2 }}>{c.sub}</div>
                  </div>
                  {cadence === c.id && <span style={{ color: "#e8d5b0" }}>✓</span>}
                </button>
              ))}
            </div>
            <button
              className="pill-btn"
              disabled={!cadence}
              onClick={() => go("invite")}
            >Next →</button>
          </div>
        )}

        {/* STEP 4 — Invite */}
        {screen === "invite" && (
          <div className={`screen ${animating ? "out" : ""}`}>
            <button className="back-btn" onClick={() => go("create-cadence")}>← back</button>
            <p className="label">Step 4 of 4 · Invite</p>
            <h1 className="headline">Bring your people in.</h1>
            <p className="sub">Share a link — they can RSVP without signing up.</p>

            <div style={{ background: "#141414", borderRadius: 16, padding: "20px", marginBottom: 20, border: "1px solid #252525" }}>
              <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: "#555", letterSpacing: "0.08em", textTransform: "uppercase", marginBottom: 12 }}>Your hangout</div>
              <div style={{ fontFamily: "'Playfair Display', serif", fontSize: 20, color: "#f0e8d8", marginBottom: 6 }}>{finalName || "Drinks"}</div>
              <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 14, color: "#888" }}>
                {selectedDate === "pick" ? "Date TBD" : selectedDate} · {CADENCES.find(c => c.id === cadence)?.label || "Weekly"}
              </div>
            </div>

            <div className="invite-link" style={{ marginBottom: 12 }}>
              <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#555", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                stilon.app/join/drinks-fri-3k9x
              </span>
              <button className="copy-btn">Copy link</button>
            </div>

            <div style={{ display: "flex", gap: 10, marginBottom: 24 }}>
              <button className="ghost-btn" style={{ flex: 1 }}>
                📱 iMessage
              </button>
              <button className="ghost-btn" style={{ flex: 1 }}>
                💬 WhatsApp
              </button>
            </div>

            <button className="pill-btn" onClick={() => go("confirmation")}>
              Create hangout →
            </button>
            <p className="annotation">Takes 5 seconds to RSVP</p>
          </div>
        )}

        {/* CONFIRMATION */}
        {screen === "confirmation" && (
          <div className="screen" style={{ textAlign: "center", padding: "40px 0" }}>
            <div style={{ marginBottom: 20 }}>
              <span className="ember" style={{ width: 16, height: 16 }} />
            </div>
            <h1 style={{ fontFamily: "'Playfair Display', serif", fontSize: 30, color: "#f0e8d8", marginBottom: 12 }}>
              {finalName || "Drinks"} is on.
            </h1>
            <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 15, color: "#666", lineHeight: 1.6, marginBottom: 36 }}>
              We'll send everyone a "Still on?" text<br />2 days before. You're all set.
            </p>
            <div style={{
              background: "#141414",
              border: "1px solid #252525",
              borderRadius: 16,
              padding: "20px 24px",
              marginBottom: 32,
              textAlign: "left",
            }}>
              {[
                ["Hangout", finalName || "Drinks"],
                ["First date", selectedDate === "pick" ? "TBD" : selectedDate],
                ["Cadence", CADENCES.find(c => c.id === cadence)?.label || "Weekly"],
                ["Reminder", "2 days before, via SMS"],
              ].map(([k, v]) => (
                <div key={k} style={{ display: "flex", justifyContent: "space-between", marginBottom: 12 }}>
                  <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#555" }}>{k}</span>
                  <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#ccc", fontWeight: 500 }}>{v}</span>
                </div>
              ))}
            </div>
            <button className="pill-btn" onClick={() => { setScreen("phone"); setCode(["","","","","",""]); setPhone(""); setHangoutName(""); setCadence(null); setSelectedDate(null); }}>
              Start another
            </button>
            <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: "#444", marginTop: 16 }}>
              Restart demo ↑
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
