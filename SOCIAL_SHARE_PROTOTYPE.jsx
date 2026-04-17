import { useState, useEffect, useRef } from "react";

// ─── Design Tokens (matching FBLA Connect "Contender" system) ────────────
const T = {
  primary: "#2563EB",
  primaryLight: "#3B82F6",
  primaryDark: "#1D4ED8",
  gold: "#F5A623",
  goldLight: "#FBBF24",
  goldDark: "#D97706",
  darkBg: "#09090E",
  darkSurface: "#111118",
  darkSurfaceHigh: "#18181F",
  darkOverlay: "#0D0D13",
  darkOutline: "#252432",
  darkOutlineVar: "#1D1C28",
  textPrimary: "#EEEFF7",
  textSecond: "#8381A0",
  textTertiary: "#494862",
  success: "#16A34A",
  error: "#DC2626",
  onSecondary: "#0D0C17",
  warmWhite: "#F8F7F3",
};

const font = {
  display: "'Josefin Sans', sans-serif",
  body: "'Mulish', sans-serif",
  mono: "'JetBrains Mono', monospace",
};

// ─── Shared styles ───────────────────────────────────────────────────────
const pill = (active, color = T.primary) => ({
  padding: "6px 14px",
  borderRadius: 999,
  fontSize: 12,
  fontFamily: font.body,
  fontWeight: 600,
  letterSpacing: "0.02em",
  border: `1px solid ${active ? color : T.darkOutline}`,
  background: active ? color : "transparent",
  color: active ? "#fff" : T.textSecond,
  cursor: "pointer",
  transition: "all 200ms cubic-bezier(0.23, 1, 0.32, 1)",
});

// ─── Phone Frame ─────────────────────────────────────────────────────────
function PhoneFrame({ children, label }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 12 }}>
      {label && (
        <span style={{ fontFamily: font.display, fontSize: 13, fontWeight: 600, color: T.textSecond, letterSpacing: "0.04em", textTransform: "uppercase" }}>
          {label}
        </span>
      )}
      <div style={{
        width: 375, height: 720, background: T.darkBg, borderRadius: 40,
        border: `2px solid ${T.darkOutline}`, overflow: "hidden", position: "relative",
        boxShadow: "0 24px 80px rgba(0,0,0,0.5)",
      }}>
        {/* Status bar */}
        <div style={{
          height: 44, display: "flex", alignItems: "center", justifyContent: "center",
          padding: "0 24px", position: "relative", zIndex: 10,
        }}>
          <div style={{ width: 80, height: 24, borderRadius: 12, background: T.darkSurface }} />
        </div>
        <div style={{ height: 676, overflow: "hidden", position: "relative" }}>
          {children}
        </div>
      </div>
    </div>
  );
}

// ─── Celebration Screen ──────────────────────────────────────────────────
function CelebrationScreen({ contentType = "event", chapterName = "Lincoln High FBLA", onShare, sharedPlatforms = [] }) {
  const [visible, setVisible] = useState(false);
  const [step, setStep] = useState(0);

  useEffect(() => {
    setVisible(false);
    setStep(0);
    const t0 = setTimeout(() => setStep(1), 50);
    const t1 = setTimeout(() => setStep(2), 200);
    const t2 = setTimeout(() => setStep(3), 400);
    const t3 = setTimeout(() => setStep(4), 550);
    setVisible(true);
    return () => { clearTimeout(t0); clearTimeout(t1); clearTimeout(t2); clearTimeout(t3); };
  }, []);

  const shareOptions = [
    { id: "instagram", icon: "📷", name: "Instagram", desc: "Stories" },
    { id: "twitter", icon: "𝕏", name: "X / Twitter", desc: "Post" },
    { id: "native", icon: "↗", name: "More", desc: "Share" },
  ];

  return (
    <div style={{
      height: "100%", display: "flex", flexDirection: "column",
      alignItems: "center", justifyContent: "center",
      padding: "0 32px", background: T.darkBg,
    }}>
      {/* Gold checkmark */}
      <div style={{
        width: 72, height: 72, borderRadius: "50%",
        background: `linear-gradient(135deg, ${T.gold}, ${T.goldDark})`,
        display: "flex", alignItems: "center", justifyContent: "center",
        transform: step >= 1 ? "scale(1)" : "scale(0.85)",
        opacity: step >= 1 ? 1 : 0,
        transition: "all 300ms cubic-bezier(0.23, 1, 0.32, 1)",
        boxShadow: `0 8px 32px ${T.gold}33`,
      }}>
        <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke={T.onSecondary} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="20 6 9 17 4 12" />
        </svg>
      </div>

      {/* Headline */}
      <h1 style={{
        fontFamily: font.display, fontSize: 28, fontWeight: 600,
        color: T.textPrimary, margin: "24px 0 8px",
        opacity: step >= 2 ? 1 : 0,
        transform: step >= 2 ? "translateY(0)" : "translateY(8px)",
        transition: "all 250ms cubic-bezier(0.23, 1, 0.32, 1)",
      }}>
        Published!
      </h1>

      {/* Subline */}
      <p style={{
        fontFamily: font.body, fontSize: 15, color: T.textSecond,
        textAlign: "center", margin: 0, lineHeight: 1.5,
        opacity: step >= 3 ? 1 : 0,
        transform: step >= 3 ? "translateY(0)" : "translateY(6px)",
        transition: "all 250ms cubic-bezier(0.23, 1, 0.32, 1)",
      }}>
        Your {contentType} is now live for {chapterName}.
      </p>

      {/* Share section */}
      <div style={{ marginTop: 48, width: "100%" }}>
        <span style={{
          fontFamily: font.display, fontSize: 11, fontWeight: 500,
          color: T.textTertiary, letterSpacing: "0.08em", textTransform: "uppercase",
          display: "block", textAlign: "center", marginBottom: 20,
          opacity: step >= 4 ? 1 : 0,
          transition: "opacity 200ms ease",
        }}>
          Share with your community
        </span>

        <div style={{ display: "flex", gap: 12, justifyContent: "center" }}>
          {shareOptions.map((opt, i) => {
            const shared = sharedPlatforms.includes(opt.id);
            return (
              <button
                key={opt.id}
                onClick={() => onShare?.(opt.id)}
                style={{
                  flex: 1, maxWidth: 100, padding: "20px 8px 16px",
                  background: T.darkSurface, border: `1px solid ${T.darkOutline}`,
                  borderRadius: 16, cursor: "pointer", position: "relative",
                  display: "flex", flexDirection: "column", alignItems: "center", gap: 8,
                  opacity: step >= 4 ? 1 : 0,
                  transform: step >= 4 ? "translateY(0)" : "translateY(10px)",
                  transition: `all 250ms cubic-bezier(0.23, 1, 0.32, 1) ${i * 50}ms`,
                }}
                onMouseDown={e => e.currentTarget.style.transform = "scale(0.97)"}
                onMouseUp={e => e.currentTarget.style.transform = "scale(1)"}
                onMouseLeave={e => e.currentTarget.style.transform = "scale(1)"}
              >
                {shared && (
                  <div style={{
                    position: "absolute", top: 6, right: 6,
                    width: 14, height: 14, borderRadius: "50%",
                    background: T.gold, display: "flex", alignItems: "center", justifyContent: "center",
                  }}>
                    <svg width="8" height="8" viewBox="0 0 24 24" fill="none" stroke={T.onSecondary} strokeWidth="3" strokeLinecap="round"><polyline points="20 6 9 17 4 12" /></svg>
                  </div>
                )}
                <span style={{ fontSize: 24, lineHeight: 1 }}>{opt.icon}</span>
                <span style={{ fontFamily: font.body, fontSize: 12, fontWeight: 600, color: T.textPrimary }}>
                  {opt.name}
                </span>
                <span style={{ fontFamily: font.body, fontSize: 11, color: T.textTertiary }}>
                  {opt.desc}
                </span>
              </button>
            );
          })}
        </div>
      </div>

      {/* Done button */}
      <button style={{
        position: "absolute", bottom: 32, left: "50%", transform: "translateX(-50%)",
        background: "none", border: "none", cursor: "pointer",
        fontFamily: font.body, fontSize: 15, color: T.textSecond,
        padding: "12px 24px",
      }}>
        Done
      </button>
    </div>
  );
}

// ─── Instagram Template Picker ───────────────────────────────────────────
function TemplatePicker({ contentTitle = "State Leadership Conference", contentDate = "May 15, 2026", contentLocation = "Sacramento Convention Center", chapterName = "Lincoln High FBLA", onSelect, onBack }) {
  const [selected, setSelected] = useState(null);

  const templates = [
    {
      id: "bold",
      name: "Bold",
      bg: `linear-gradient(135deg, ${T.gold}, ${T.goldDark})`,
      titleColor: "#fff",
      detailColor: "rgba(255,255,255,0.7)",
    },
    {
      id: "clean",
      name: "Clean",
      bg: T.warmWhite,
      titleColor: T.primary,
      detailColor: T.textSecond,
    },
    {
      id: "dark",
      name: "Dark",
      bg: T.darkBg,
      titleColor: T.gold,
      detailColor: T.textSecond,
    },
  ];

  return (
    <div style={{
      background: T.darkOverlay, borderTop: `1px solid ${T.darkOutline}`,
      borderRadius: "20px 20px 0 0", padding: "20px 16px 32px",
      position: "absolute", bottom: 0, left: 0, right: 0,
    }}>
      {/* Drag handle */}
      <div style={{ width: 36, height: 4, borderRadius: 2, background: T.darkOutlineVar, margin: "0 auto 20px" }} />

      <div style={{ display: "flex", alignItems: "center", marginBottom: 20 }}>
        <button onClick={onBack} style={{ background: "none", border: "none", cursor: "pointer", color: T.textSecond, fontFamily: font.body, fontSize: 14, padding: "4px 0" }}>
          ← Back
        </button>
        <span style={{ flex: 1, textAlign: "center", fontFamily: font.display, fontSize: 16, fontWeight: 600, color: T.textPrimary }}>
          Choose a style
        </span>
        <div style={{ width: 48 }} />
      </div>

      {/* Template previews */}
      <div style={{ display: "flex", gap: 12, overflowX: "auto", paddingBottom: 8 }}>
        {templates.map((tmpl) => (
          <button
            key={tmpl.id}
            onClick={() => { setSelected(tmpl.id); onSelect?.(tmpl.id); }}
            style={{
              flex: "0 0 120px", height: 213, borderRadius: 12, overflow: "hidden",
              background: tmpl.bg, border: selected === tmpl.id ? `2px solid ${T.gold}` : `1px solid ${T.darkOutline}`,
              cursor: "pointer", display: "flex", flexDirection: "column",
              justifyContent: "center", alignItems: "center", padding: 12,
              position: "relative",
              transition: "border 200ms ease",
            }}
            onMouseDown={e => e.currentTarget.style.transform = "scale(0.97)"}
            onMouseUp={e => e.currentTarget.style.transform = "scale(1)"}
            onMouseLeave={e => e.currentTarget.style.transform = "scale(1)"}
          >
            {/* Mini preview content */}
            <span style={{
              fontFamily: font.display, fontSize: 10, fontWeight: 700,
              color: tmpl.titleColor, textAlign: "center", lineHeight: 1.3,
              marginBottom: 4,
            }}>
              {contentTitle}
            </span>
            {tmpl.id === "clean" && (
              <div style={{ width: 24, height: 1.5, background: T.gold, margin: "4px 0" }} />
            )}
            <span style={{
              fontFamily: font.body, fontSize: 7, color: tmpl.detailColor,
              textAlign: "center",
            }}>
              {contentDate}
            </span>
            <span style={{
              fontFamily: font.body, fontSize: 6, color: tmpl.detailColor,
              textAlign: "center", marginTop: 2, opacity: 0.7,
            }}>
              {chapterName}
            </span>

            {/* Template name label */}
            <span style={{
              position: "absolute", bottom: 8,
              fontFamily: font.body, fontSize: 9, fontWeight: 600,
              color: tmpl.id === "dark" ? T.textTertiary : (tmpl.id === "bold" ? "rgba(255,255,255,0.6)" : T.textTertiary),
              letterSpacing: "0.05em", textTransform: "uppercase",
            }}>
              {tmpl.name}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ─── Share Bottom Sheet (persistent card share) ──────────────────────────
function ShareSheet({ onShare, onClose, showTemplates, setShowTemplates }) {
  const options = [
    { id: "instagram", icon: "📷", name: "Instagram Stories", desc: "Share a branded card" },
    { id: "twitter", icon: "𝕏", name: "X / Twitter", desc: "Post with your chapter" },
    { id: "native", icon: "↗", name: "More options", desc: "Share via any app" },
  ];

  if (showTemplates) {
    return (
      <TemplatePicker
        onSelect={(id) => { onShare?.("instagram"); }}
        onBack={() => setShowTemplates(false)}
      />
    );
  }

  return (
    <div style={{
      background: T.darkOverlay, borderTop: `1px solid ${T.darkOutline}`,
      borderRadius: "20px 20px 0 0", padding: "16px 16px 32px",
      position: "absolute", bottom: 0, left: 0, right: 0,
    }}>
      <div style={{ width: 36, height: 4, borderRadius: 2, background: T.darkOutlineVar, margin: "0 auto 16px" }} />

      {options.map((opt) => (
        <button
          key={opt.id}
          onClick={() => {
            if (opt.id === "instagram") { setShowTemplates(true); }
            else { onShare?.(opt.id); }
          }}
          style={{
            width: "100%", display: "flex", alignItems: "center", gap: 14,
            padding: "14px 12px", background: "none", border: "none",
            borderRadius: 12, cursor: "pointer",
            transition: "background 150ms ease",
          }}
          onMouseEnter={e => e.currentTarget.style.background = T.darkSurface}
          onMouseLeave={e => e.currentTarget.style.background = "transparent"}
          onMouseDown={e => e.currentTarget.style.transform = "scale(0.99)"}
          onMouseUp={e => e.currentTarget.style.transform = "scale(1)"}
        >
          <span style={{
            width: 40, height: 40, borderRadius: 10,
            background: T.darkSurfaceHigh, display: "flex",
            alignItems: "center", justifyContent: "center", fontSize: 18,
            border: `1px solid ${T.darkOutline}`,
          }}>
            {opt.icon}
          </span>
          <div style={{ textAlign: "left" }}>
            <div style={{ fontFamily: font.body, fontSize: 15, fontWeight: 600, color: T.textPrimary }}>
              {opt.name}
            </div>
            <div style={{ fontFamily: font.body, fontSize: 12, color: T.textTertiary, marginTop: 1 }}>
              {opt.desc}
            </div>
          </div>
          <svg style={{ marginLeft: "auto" }} width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={T.textTertiary} strokeWidth="2" strokeLinecap="round">
            <polyline points="9 18 15 12 9 6" />
          </svg>
        </button>
      ))}
    </div>
  );
}

// ─── Events Tab with Interactive Calendar ────────────────────────────────
function EventsTab() {
  const [currentMonth, setCurrentMonth] = useState(new Date(2026, 3)); // April 2026
  const [selectedDay, setSelectedDay] = useState(15);
  const [scope, setScope] = useState("all");

  const daysInMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 0).getDate();
  const firstDayOfWeek = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1).getDay();
  const monthName = currentMonth.toLocaleDateString("en-US", { month: "long", year: "numeric" });

  const eventDays = [3, 8, 12, 15, 22, 28]; // Mock: days with events

  const mockEvents = [
    { title: "State Leadership Conference", location: "Sacramento Convention Center", date: "Apr 15", time: "9:00 AM", urgent: "Today", hasImage: true },
    { title: "Chapter Meeting", location: "Room 204, Lincoln High", date: "Apr 22", time: "3:30 PM", urgent: "7 days", hasImage: false },
    { title: "Networking Workshop", location: "Downtown Business Center", date: "Apr 28", time: "6:00 PM", urgent: "13 days", hasImage: false },
  ];

  const dayLabels = ["S", "M", "T", "W", "T", "F", "S"];

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", background: T.darkBg }}>
      {/* App Bar */}
      <div style={{
        padding: "12px 20px", display: "flex", alignItems: "center", justifyContent: "space-between",
      }}>
        <h1 style={{ fontFamily: font.display, fontSize: 22, fontWeight: 600, color: T.textPrimary, margin: 0 }}>
          Events
        </h1>
        <div style={{
          width: 32, height: 32, borderRadius: 8, background: T.darkSurface,
          border: `1px solid ${T.darkOutline}`, display: "flex", alignItems: "center", justifyContent: "center",
          cursor: "pointer",
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={T.textSecond} strokeWidth="2" strokeLinecap="round">
            <line x1="4" y1="8" x2="20" y2="8" /><line x1="4" y1="16" x2="20" y2="16" />
          </svg>
        </div>
      </div>

      {/* ── Calendar (top ~45%) ────────────────────────────────────────── */}
      <div style={{ padding: "0 16px 12px", flexShrink: 0 }}>
        {/* Month nav */}
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 24, marginBottom: 16 }}>
          <button
            onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() - 1))}
            style={{ background: "none", border: "none", cursor: "pointer", color: T.textSecond, fontSize: 18, padding: 4 }}
          >
            ‹
          </button>
          <span style={{ fontFamily: font.display, fontSize: 16, fontWeight: 600, color: T.textPrimary, minWidth: 160, textAlign: "center" }}>
            {monthName}
          </span>
          <button
            onClick={() => setCurrentMonth(new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1))}
            style={{ background: "none", border: "none", cursor: "pointer", color: T.textSecond, fontSize: 18, padding: 4 }}
          >
            ›
          </button>
        </div>

        {/* Day-of-week labels */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 0, marginBottom: 4 }}>
          {dayLabels.map((d, i) => (
            <div key={i} style={{
              textAlign: "center", fontFamily: font.body, fontSize: 11,
              fontWeight: 600, color: T.textTertiary, padding: "4px 0",
              letterSpacing: "0.04em",
            }}>
              {d}
            </div>
          ))}
        </div>

        {/* Day grid */}
        <div style={{ display: "grid", gridTemplateColumns: "repeat(7, 1fr)", gap: 2 }}>
          {/* Empty cells before first day */}
          {Array.from({ length: firstDayOfWeek }, (_, i) => (
            <div key={`empty-${i}`} style={{ height: 44 }} />
          ))}

          {/* Day cells */}
          {Array.from({ length: daysInMonth }, (_, i) => {
            const day = i + 1;
            const isSelected = day === selectedDay;
            const isToday = day === 12; // April 12 is today
            const hasEvent = eventDays.includes(day);
            const isPast = day < 12;

            return (
              <button
                key={day}
                onClick={() => setSelectedDay(day)}
                style={{
                  width: "100%", height: 44, borderRadius: 12, border: "none",
                  background: isSelected
                    ? T.gold
                    : isToday
                      ? T.primary
                      : "transparent",
                  cursor: "pointer",
                  display: "flex", flexDirection: "column",
                  alignItems: "center", justifyContent: "center", gap: 2,
                  transition: "all 0ms", // No animation — high-frequency action
                }}
              >
                <span style={{
                  fontFamily: font.body, fontSize: 14, fontWeight: isSelected || isToday ? 700 : 400,
                  color: isSelected
                    ? T.onSecondary
                    : isToday
                      ? "#fff"
                      : isPast
                        ? T.textTertiary
                        : T.textPrimary,
                }}>
                  {day}
                </span>
                {hasEvent && !isSelected && !isToday && (
                  <div style={{
                    width: 4, height: 4, borderRadius: 2,
                    background: T.primary,
                  }} />
                )}
                {hasEvent && (isSelected || isToday) && (
                  <div style={{
                    width: 4, height: 4, borderRadius: 2,
                    background: isSelected ? T.onSecondary : "rgba(255,255,255,0.7)",
                  }} />
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* ── Divider / drag handle ──────────────────────────────────────── */}
      <div style={{ display: "flex", justifyContent: "center", padding: "8px 0" }}>
        <div style={{ width: 36, height: 3, borderRadius: 1.5, background: T.darkOutlineVar }} />
      </div>

      {/* ── Scope filters ──────────────────────────────────────────────── */}
      <div style={{ padding: "0 16px 12px", display: "flex", gap: 8 }}>
        {["all", "chapter", "district"].map((s) => (
          <button
            key={s}
            onClick={() => setScope(s)}
            style={pill(scope === s)}
          >
            {s === "all" ? "All Events" : s.charAt(0).toUpperCase() + s.slice(1)}
          </button>
        ))}
      </div>

      {/* ── Event List (scrollable bottom) ─────────────────────────────── */}
      <div style={{ flex: 1, overflowY: "auto", padding: "0 16px 80px" }}>
        {mockEvents.map((evt, i) => (
          <div
            key={i}
            style={{
              marginBottom: 12, borderRadius: 16, overflow: "hidden",
              background: evt.hasImage
                ? `linear-gradient(to bottom, rgba(0,0,0,0.15) 0%, rgba(0,0,0,0.75) 100%), linear-gradient(135deg, ${T.primaryDark}, ${T.primary})`
                : T.darkSurface,
              border: evt.hasImage ? "none" : `1px solid ${T.darkOutline}`,
              padding: evt.hasImage ? 0 : "16px",
              position: "relative",
              minHeight: evt.hasImage ? 140 : "auto",
            }}
          >
            {evt.hasImage ? (
              // Card with location background image
              <div style={{ padding: "16px", height: 140, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
                {/* Top row: date badge + urgency */}
                <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
                  <div style={{
                    background: "rgba(0,0,0,0.5)", backdropFilter: "blur(8px)",
                    borderRadius: 8, padding: "6px 10px", textAlign: "center",
                  }}>
                    <div style={{ fontFamily: font.display, fontSize: 18, fontWeight: 700, color: T.gold }}>15</div>
                    <div style={{ fontFamily: font.body, fontSize: 9, color: "rgba(255,255,255,0.7)", textTransform: "uppercase", letterSpacing: "0.05em" }}>Apr</div>
                  </div>
                  <span style={{
                    background: T.gold, color: T.onSecondary,
                    fontFamily: font.body, fontSize: 10, fontWeight: 700,
                    padding: "3px 8px", borderRadius: 6,
                  }}>
                    Today
                  </span>
                </div>
                {/* Bottom: title + location */}
                <div>
                  <div style={{ fontFamily: font.display, fontSize: 16, fontWeight: 600, color: "#fff", marginBottom: 3 }}>
                    {evt.title}
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 12, color: "rgba(255,255,255,0.65)" }}>
                    📍 {evt.location} · {evt.time}
                  </div>
                  {/* Shared badge mock */}
                  <div style={{ display: "flex", gap: 5, marginTop: 6 }}>
                    <span style={{ fontSize: 11, color: "rgba(255,255,255,0.4)" }}>📷</span>
                    <span style={{ fontSize: 11, color: "rgba(255,255,255,0.4)" }}>𝕏</span>
                  </div>
                </div>
              </div>
            ) : (
              // Standard card (no image)
              <div style={{ display: "flex", gap: 14 }}>
                {/* Date column */}
                <div style={{
                  width: 48, flexShrink: 0, textAlign: "center",
                  background: `linear-gradient(135deg, ${T.darkSurfaceHigh}, ${T.darkSurface})`,
                  borderRadius: 10, padding: "10px 4px",
                  border: `1px solid ${T.darkOutline}`,
                }}>
                  <div style={{ fontFamily: font.display, fontSize: 20, fontWeight: 700, color: T.primary }}>
                    {evt.date.split(" ")[1]}
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 9, color: T.textTertiary, textTransform: "uppercase", letterSpacing: "0.05em" }}>
                    {evt.date.split(" ")[0]}
                  </div>
                </div>
                {/* Content */}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontFamily: font.display, fontSize: 15, fontWeight: 600, color: T.textPrimary, marginBottom: 4 }}>
                    {evt.title}
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 12, color: T.textSecond }}>
                    📍 {evt.location}
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 11, color: T.textTertiary, marginTop: 4 }}>
                    {evt.time} · {evt.urgent} away
                  </div>
                </div>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* FAB (advisor) */}
      <button style={{
        position: "absolute", bottom: 24, right: 20,
        width: 52, height: 52, borderRadius: 16,
        background: T.gold, border: "none", cursor: "pointer",
        display: "flex", alignItems: "center", justifyContent: "center",
        boxShadow: `0 4px 20px ${T.gold}44`,
        transition: "transform 160ms cubic-bezier(0.23, 1, 0.32, 1)",
      }}
      onMouseDown={e => e.currentTarget.style.transform = "scale(0.95)"}
      onMouseUp={e => e.currentTarget.style.transform = "scale(1)"}
      onMouseLeave={e => e.currentTarget.style.transform = "scale(1)"}
      >
        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={T.onSecondary} strokeWidth="2.5" strokeLinecap="round">
          <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
        </svg>
      </button>
    </div>
  );
}

// ─── Post Creation Preview (Screen 2: Caption + Pre-Upload) ──────────────
function PostCreationScreen() {
  const [caption, setCaption] = useState("");
  const [uploadProgress, setUploadProgress] = useState(0);
  const [uploaded, setUploaded] = useState(false);

  useEffect(() => {
    // Simulate pre-upload
    const interval = setInterval(() => {
      setUploadProgress((prev) => {
        if (prev >= 100) { clearInterval(interval); setUploaded(true); return 100; }
        return prev + Math.random() * 15 + 5;
      });
    }, 200);
    return () => clearInterval(interval);
  }, []);

  const charCount = caption.length;

  return (
    <div style={{ height: "100%", display: "flex", flexDirection: "column", background: T.darkBg }}>
      {/* Top bar */}
      <div style={{ padding: "8px 16px", display: "flex", alignItems: "center", justifyContent: "space-between" }}>
        <button style={{ background: "none", border: "none", color: T.textSecond, fontFamily: font.body, fontSize: 15, cursor: "pointer" }}>
          ← Back
        </button>
        <span style={{ fontFamily: font.display, fontSize: 16, fontWeight: 600, color: T.textPrimary }}>
          New Post
        </span>
        <button style={{
          background: uploaded ? T.gold : T.darkSurfaceHigh,
          border: "none", borderRadius: 8, padding: "8px 16px", cursor: uploaded ? "pointer" : "default",
          fontFamily: font.display, fontSize: 13, fontWeight: 600,
          color: uploaded ? T.onSecondary : T.textTertiary,
          transition: "all 300ms cubic-bezier(0.23, 1, 0.32, 1)",
        }}>
          {uploaded ? "Share" : "Uploading..."}
        </button>
      </div>

      {/* Upload progress bar */}
      {!uploaded && (
        <div style={{ height: 2, background: T.darkSurfaceHigh }}>
          <div style={{
            height: "100%", background: T.primary,
            width: `${Math.min(uploadProgress, 100)}%`,
            transition: "width 300ms cubic-bezier(0.23, 1, 0.32, 1)",
          }} />
        </div>
      )}

      {/* Content area */}
      <div style={{ flex: 1, padding: "20px 16px", display: "flex", gap: 14 }}>
        {/* Image thumbnail */}
        <div style={{
          width: 64, height: 64, borderRadius: 10, flexShrink: 0,
          background: `linear-gradient(135deg, ${T.primaryDark}, ${T.primary})`,
          display: "flex", alignItems: "center", justifyContent: "center",
          border: `1px solid ${T.darkOutline}`,
        }}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="rgba(255,255,255,0.5)" strokeWidth="1.5">
            <rect x="3" y="3" width="18" height="18" rx="2" />
            <circle cx="8.5" cy="8.5" r="1.5" />
            <polyline points="21 15 16 10 5 21" />
          </svg>
        </div>

        {/* Caption field */}
        <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
          <textarea
            value={caption}
            onChange={(e) => setCaption(e.target.value.slice(0, 2000))}
            placeholder="Write a caption..."
            style={{
              flex: 1, background: "none", border: "none", resize: "none",
              fontFamily: font.body, fontSize: 15, lineHeight: 1.55,
              color: T.textPrimary, outline: "none",
              minHeight: 120,
            }}
          />
          {charCount > 1800 && (
            <span style={{
              fontFamily: font.mono, fontSize: 11, color: charCount > 1950 ? T.error : T.textTertiary,
              textAlign: "right", marginTop: 4,
              transition: "color 200ms ease",
            }}>
              {charCount}/2000
            </span>
          )}
        </div>
      </div>

      {/* Scope indicator */}
      <div style={{
        padding: "12px 16px", borderTop: `1px solid ${T.darkOutline}`,
        fontFamily: font.body, fontSize: 13, color: T.textTertiary,
      }}>
        Posting to <span style={{ color: T.textSecond, fontWeight: 600 }}>Lincoln High FBLA</span>
      </div>
    </div>
  );
}

// ─── Main App ────────────────────────────────────────────────────────────
export default function SocialSharePrototype() {
  const [activeScreen, setActiveScreen] = useState("celebration");
  const [sharedPlatforms, setSharedPlatforms] = useState([]);
  const [showTemplates, setShowTemplates] = useState(false);
  const [showShareSheet, setShowShareSheet] = useState(false);

  const handleShare = (platform) => {
    if (!sharedPlatforms.includes(platform)) {
      setSharedPlatforms([...sharedPlatforms, platform]);
    }
  };

  const screens = [
    { id: "celebration", label: "Celebration" },
    { id: "events", label: "Events Tab" },
    { id: "post", label: "New Post" },
    { id: "share-sheet", label: "Share Sheet" },
  ];

  return (
    <div style={{
      minHeight: "100vh", background: "#06060A",
      display: "flex", flexDirection: "column", alignItems: "center",
      padding: "40px 20px 60px",
      fontFamily: font.body,
    }}>
      {/* Google Fonts */}
      <link href="https://fonts.googleapis.com/css2?family=Josefin+Sans:wght@400;500;600;700&family=Mulish:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet" />

      {/* Title */}
      <h1 style={{
        fontFamily: font.display, fontSize: 28, fontWeight: 600,
        color: T.textPrimary, margin: "0 0 4px", textAlign: "center",
      }}>
        FBLA Connect — Share & Post Redesign
      </h1>
      <p style={{
        fontFamily: font.body, fontSize: 14, color: T.textSecond,
        margin: "0 0 32px", textAlign: "center",
      }}>
        Interactive prototype of the key flows
      </p>

      {/* Screen selector */}
      <div style={{ display: "flex", gap: 8, marginBottom: 40, flexWrap: "wrap", justifyContent: "center" }}>
        {screens.map((s) => (
          <button
            key={s.id}
            onClick={() => { setActiveScreen(s.id); setShowTemplates(false); setShowShareSheet(false); }}
            style={{
              ...pill(activeScreen === s.id, T.gold),
              fontSize: 13,
              padding: "8px 18px",
            }}
          >
            {s.label}
          </button>
        ))}
      </div>

      {/* Phone frames */}
      <div style={{ display: "flex", gap: 32, flexWrap: "wrap", justifyContent: "center" }}>
        {activeScreen === "celebration" && (
          <PhoneFrame label="After Publishing">
            <CelebrationScreen
              contentType="event"
              chapterName="Lincoln High FBLA"
              onShare={handleShare}
              sharedPlatforms={sharedPlatforms}
            />
          </PhoneFrame>
        )}

        {activeScreen === "events" && (
          <PhoneFrame label="Events Tab">
            <EventsTab />
          </PhoneFrame>
        )}

        {activeScreen === "post" && (
          <PhoneFrame label="Caption + Pre-Upload">
            <PostCreationScreen />
          </PhoneFrame>
        )}

        {activeScreen === "share-sheet" && (
          <PhoneFrame label="Share from Card">
            <div style={{ height: "100%", background: T.darkBg, position: "relative" }}>
              {/* Mock card behind */}
              <div style={{ padding: "16px", opacity: showTemplates ? 0.3 : 0.5, transition: "opacity 300ms ease" }}>
                <div style={{
                  background: T.darkSurface, border: `1px solid ${T.darkOutline}`,
                  borderRadius: 16, padding: 16,
                }}>
                  <div style={{ fontFamily: font.display, fontSize: 15, fontWeight: 600, color: T.textPrimary, marginBottom: 8 }}>
                    State Leadership Conference
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 13, color: T.textSecond, marginBottom: 4 }}>
                    Join us for the annual SLC at the Sacramento Convention Center...
                  </div>
                  <div style={{ fontFamily: font.body, fontSize: 11, color: T.textTertiary }}>
                    Apr 15, 2026 · Sacramento, CA
                  </div>
                </div>
              </div>

              {/* Share sheet */}
              <ShareSheet
                onShare={handleShare}
                onClose={() => setShowShareSheet(false)}
                showTemplates={showTemplates}
                setShowTemplates={setShowTemplates}
              />
            </div>
          </PhoneFrame>
        )}
      </div>

      {/* Shared platforms indicator */}
      {sharedPlatforms.length > 0 && (
        <div style={{
          marginTop: 24, fontFamily: font.body, fontSize: 12, color: T.textTertiary,
          display: "flex", alignItems: "center", gap: 8,
        }}>
          Shared to: {sharedPlatforms.map(p => (
            <span key={p} style={{
              background: T.darkSurface, border: `1px solid ${T.darkOutline}`,
              borderRadius: 6, padding: "3px 8px", fontSize: 11, color: T.textSecond,
            }}>
              {p}
            </span>
          ))}
        </div>
      )}
    </div>
  );
}
