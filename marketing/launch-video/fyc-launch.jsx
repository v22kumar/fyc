/* FYC Connect — launch demo video. Screens recreated 1:1 from the real app
   screenshots: dark navy theme, orange accent, green chess banner, and the
   Home / Feed / Play / Serve bottom nav with the central orange FAB + SOS. */

const { useScene, useTimeline, Easing, interpolate, clamp } = window;

// ── Palette (real FYC Connect app) ──────────────────────────────────────────
const C = {
  bg: '#0A0E1A', bg2: '#0B1122',
  card: '#141A2A', card2: '#1B2236', border: '#252D42', borderSoft: '#1E2740',
  orange: '#F59E0B', orangeDeep: '#F97316', orange2: '#FB923C', orangeSoft: '#7A4A12',
  green: '#17A24A', greenDeep: '#15803D', greenBright: '#22C55E', greenBanner: '#16A34A',
  teal: '#0E3A34',
  red: '#DC2626', redSoft: '#EF4444', sos: '#F43F5E',
  purple: '#7C3AED', purpleL: '#A855F7', pink: '#EC4899', blue: '#3B82F6', blueL: '#60A5FA',
  text: '#FFFFFF', text2: '#8B93A7', text3: '#5B6478',
};
const FONT = "'Plus Jakarta Sans', system-ui, sans-serif";
const TAM = "'Noto Sans Tamil', 'Plus Jakarta Sans', sans-serif";

const OPTS = { accent: C.orange, showEnglish: true };

// ── Motion helpers ──────────────────────────────────────────────────────────
const seg = (p, a = 0.14, b = 0.86) =>
  clamp(interpolate([0, a, b, 1], [0, 1, 1, 0], Easing.easeOutCubic)(p), 0, 1);
const rise = (p) => (1 - clamp(interpolate([0, 0.2], [0, 1], Easing.easeOutCubic)(p), 0, 1)) * 26;
const ken = (p, from = 1, to = 1.1) => from + (to - from) * p;

const Icon = ({ name, size = 24, color, fill = 0, style }) => (
  <span style={{
    fontFamily: "'Material Symbols Rounded'", fontWeight: 'normal', fontStyle: 'normal',
    fontSize: size, lineHeight: 1, color, display: 'inline-block',
    fontVariationSettings: `'FILL' ${fill}`, WebkitFontSmoothing: 'antialiased', ...style,
  }}>{name}</span>
);

// ── Persistent stage pieces ─────────────────────────────────────────────────
function getNarrationEl(duration) {
  let a = window.__fycNarration;
  if (!a) {
    a = document.createElement('audio');
    a.src = 'assets/audio/narration.mp3';
    a.preload = 'auto';
    a.style.display = 'none';
    a.setAttribute('data-om-exportable-video-play-start', '0');
    a.setAttribute('data-om-exportable-video-play-speed', '1');
    document.body.appendChild(a);
    window.__fycNarration = a;
  }
  if (Number.isFinite(duration)) a.setAttribute('data-om-exportable-video-play-end', String(duration));
  return a;
}

function Narration() {
  const { time, duration, playing } = useTimeline();
  React.useEffect(() => {
    const a = getNarrationEl(duration);
    if (Number.isFinite(time) && Math.abs(a.currentTime - time) > 0.4) {
      try { a.currentTime = time; } catch (e) {}
    }
    if (playing && a.paused) a.play().catch(() => {});
    if (!playing && !a.paused) a.pause();
  }, [Math.round((time || 0) * 4), playing, duration]);
  return null;
}

function Backdrop({ tint }) {
  return (
    <React.Fragment>
      <Narration />
      <div style={{
        position: 'absolute', inset: 0,
        background: tint || `radial-gradient(120% 120% at 80% 8%, #12203A 0%, ${C.bg} 60%)`,
      }} />
    </React.Fragment>
  );
}

function Watermark({ opacity = 1 }) {
  return (
    <div style={{ position: 'absolute', left: 54, top: 44, display: 'flex', alignItems: 'center', gap: 12, opacity }}>
      <img src="assets/logos/fyc_app_icon.png" style={{ width: 40, height: 40, borderRadius: 12 }} />
      <div style={{ color: '#fff', fontFamily: FONT, fontWeight: 800, fontSize: 20, letterSpacing: '-0.02em' }}>FYC Connect</div>
    </div>
  );
}

function Caption({ tamil, english, chips, accent, p }) {
  const op = seg(p), ty = rise(p);
  return (
    <div style={{ position: 'absolute', left: 80, top: 172, width: 500, opacity: op, transform: `translateY(${ty}px)` }}>
      <div style={{
        display: 'inline-flex', alignItems: 'center', gap: 8, padding: '7px 14px', borderRadius: 999,
        background: 'rgba(255,255,255,0.06)', border: `1px solid ${accent}55`, marginBottom: 22,
      }}>
        <span style={{ width: 8, height: 8, borderRadius: 999, background: accent }} />
        <span style={{ color: accent, fontFamily: FONT, fontWeight: 700, fontSize: 15, letterSpacing: '0.08em' }}>FYC CONNECT</span>
      </div>
      <div style={{ color: '#fff', fontFamily: TAM, fontWeight: 800, fontSize: 50, lineHeight: 1.2, letterSpacing: '-0.01em', whiteSpace: 'pre-line' }}>{tamil}</div>
      {OPTS.showEnglish && (
        <div style={{ color: '#AEB7CE', fontFamily: FONT, fontWeight: 500, fontSize: 24, marginTop: 14, lineHeight: 1.4 }}>{english}</div>
      )}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 30 }}>
        {chips.map((c, i) => {
          const cp = clamp((seg(p) - 0.1) * 3 - i * 0.18, 0, 1);
          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 8, padding: '10px 15px', borderRadius: 14,
              background: 'rgba(255,255,255,0.05)', border: '1px solid rgba(255,255,255,0.1)',
              opacity: cp, transform: `translateY(${(1 - cp) * 10}px)`,
            }}>
              <Icon name={c.icon} size={20} color={accent} />
              <span style={{ color: '#E7EBF6', fontFamily: FONT, fontWeight: 600, fontSize: 16 }}>{c.label}</span>
            </div>
          );
        })}
      </div>
    </div>
  );
}

function Touch({ x, y, press = 0, show = 1 }) {
  return (
    <div style={{ position: 'absolute', left: x, top: y, zIndex: 30, transform: 'translate(-50%,-50%)', opacity: show, pointerEvents: 'none' }}>
      <div style={{ width: 34, height: 34, borderRadius: 999, background: 'rgba(245,158,11,0.28)', border: '2px solid rgba(255,255,255,0.85)', transform: `scale(${1 - press * 0.25})` }} />
    </div>
  );
}

// ── Phone shell (green chess banner + bottom nav + FAB + SOS) ────────────────
const NAV = [
  { key: 'home', icon: 'home', label: 'Home' },
  { key: 'feed', icon: 'dynamic_feed', label: 'Feed' },
  { key: 'play', icon: 'sports_cricket', label: 'Play' },
  { key: 'serve', icon: 'volunteer_activism', label: 'Serve' },
];

function ChessBanner() {
  return (
    <div style={{
      position: 'absolute', top: 0, left: 0, right: 0, height: 26, background: C.greenBanner, zIndex: 12,
      display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '0 12px',
    }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <span style={{ fontSize: 12 }}>♟</span>
        <span style={{ color: '#fff', fontFamily: FONT, fontWeight: 700, fontSize: 10 }}>Your chess game is ready — tap to join</span>
      </div>
      <Icon name="arrow_forward" size={13} color="#fff" />
    </div>
  );
}

function BottomNav({ active }) {
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0, height: 50, background: C.bg2,
      borderTop: `1px solid ${C.borderSoft}`, display: 'flex', alignItems: 'center', justifyContent: 'space-around', zIndex: 10,
    }}>
      {NAV.map((t) => {
        const on = t.key === active;
        return (
          <div key={t.key} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2, width: 58 }}>
            <div style={{ padding: on ? '2px 14px' : 0, borderRadius: 999, background: on ? C.teal : 'transparent' }}>
              <Icon name={t.icon} size={19} color={on ? C.greenBright : C.text2} fill={on ? 1 : 0} />
            </div>
            <span style={{ fontSize: 9.5, fontWeight: on ? 700 : 600, color: on ? '#fff' : C.text2, fontFamily: FONT }}>{t.label}</span>
          </div>
        );
      })}
      <div style={{
        position: 'absolute', left: '50%', top: -20, transform: 'translateX(-50%)', width: 46, height: 46, borderRadius: 999,
        background: C.orange, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 8px 20px -6px rgba(245,158,11,0.7)', border: `3px solid ${C.bg}`,
      }}>
        <Icon name="add" size={26} color="#fff" />
      </div>
    </div>
  );
}

function Phone({ children, p, x = 792, activeTab = 'home', sos = true }) {
  const op = seg(p);
  const slide = (1 - clamp(interpolate([0, 0.24], [0, 1], Easing.easeOutCubic)(p), 0, 1)) * 46;
  return (
    <div style={{ position: 'absolute', left: x, top: 66, width: 322, height: 588, opacity: op, transform: `translateX(${slide}px)` }}>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: 44, background: '#05070F', border: '9px solid #05070F',
        boxShadow: '0 40px 90px -30px rgba(0,0,0,0.75), 0 0 0 2px rgba(255,255,255,0.06)', overflow: 'hidden',
      }}>
        <div style={{ position: 'absolute', inset: 0, borderRadius: 36, overflow: 'hidden', background: C.bg }}>
          <ChessBanner />
          <div style={{ position: 'absolute', top: 26, left: 0, right: 0, bottom: 50, overflow: 'hidden' }}>{children}</div>
          {sos && (
            <div style={{
              position: 'absolute', right: 12, bottom: 62, width: 42, height: 42, borderRadius: 999, background: C.sos,
              color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: FONT, fontWeight: 800,
              fontSize: 11, zIndex: 9, boxShadow: '0 6px 16px -4px rgba(244,63,94,0.6)',
            }}>SOS</div>
          )}
          <BottomNav active={activeTab} />
        </div>
      </div>
    </div>
  );
}

// shared headers
function AppHeader() {
  return (
    <div style={{ padding: '12px 14px 0' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
          <img src="assets/logos/fyc_app_icon.png" style={{ width: 30, height: 30, borderRadius: 999, border: `1px solid ${C.border}` }} />
          <span style={{ color: '#fff', fontFamily: FONT, fontWeight: 800, fontSize: 15 }}>FYC Connect</span>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={{ width: 30, height: 30, borderRadius: 999, background: C.card, border: `1px solid ${C.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="translate" size={16} color={C.text2} /></div>
          <div style={{ position: 'relative', width: 30, height: 30, borderRadius: 999, background: C.card, border: `1px solid ${C.border}`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <Icon name="notifications" size={16} color={C.text2} />
            <div style={{ position: 'absolute', top: -3, right: -3, background: C.red, color: '#fff', borderRadius: 999, fontSize: 8, fontWeight: 800, padding: '1px 4px', fontFamily: FONT }}>9+</div>
          </div>
          <div style={{ width: 30, height: 30, borderRadius: 999, background: '#2A3350', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: FONT, fontWeight: 700, fontSize: 12 }}>V</div>
        </div>
      </div>
      <div style={{ marginTop: 11, display: 'flex', alignItems: 'center', gap: 8, background: C.card, border: `1px solid ${C.border}`, borderRadius: 12, padding: '10px 12px' }}>
        <Icon name="search" size={17} color={C.text2} />
        <span style={{ color: C.text2, fontSize: 12, flex: 1, fontFamily: FONT }}>Search services, events, and more…</span>
        <Icon name="tune" size={15} color={C.text2} />
      </div>
    </div>
  );
}

function BackHeader({ title, sub, right }) {
  return (
    <div style={{ padding: '14px 14px 12px', display: 'flex', alignItems: 'center', gap: 12 }}>
      <Icon name="arrow_back" size={22} color="#fff" />
      <div style={{ flex: 1 }}>
        <div style={{ color: '#fff', fontFamily: FONT, fontWeight: 800, fontSize: 18 }}>{title}</div>
        {sub && <div style={{ color: C.text2, fontFamily: FONT, fontSize: 11, marginTop: 1 }}>{sub}</div>}
      </div>
      {right && <div style={{ display: 'flex', alignItems: 'center', gap: 5, color: C.orange, fontFamily: FONT, fontWeight: 700, fontSize: 13 }}>{right.icon && <Icon name={right.icon} size={16} color={C.orange} />}{right.label}</div>}
    </div>
  );
}

const scrollY = (p, dist) => interpolate([0.14, 0.92], [0, -dist], Easing.easeInOutCubic)(p);

// ═══════════ SCREEN VIEWS ═══════════
function HomeScreenView({ p }) {
  const y = scrollY(p, 300);
  const cards = [
    { title: 'Blood Donation', sub: 'Verified donors near you', icon: 'bloodtype', c: '#4A1620', ic: C.red },
    { title: 'Sports Arena', sub: 'Tournaments, chess & live scores', icon: 'sports_cricket', c: '#3A2A12', ic: C.orange },
    { title: 'Community Feed', sub: 'Threads, gallery & updates', icon: 'dynamic_feed', c: '#3A2410', ic: C.orange },
    { title: 'Report an Issue', sub: 'Civic complaints, tracked to fix', icon: 'campaign', c: '#33330F', ic: '#CBB023' },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ transform: `translateY(${y}px)` }}>
        <AppHeader />
        <div style={{ padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
            <div style={{ color: '#fff', fontWeight: 800, fontSize: 15 }}>Explore FYC</div>
            <span style={{ color: C.orange, fontSize: 11, fontWeight: 700 }}>View All</span>
          </div>
          <div style={{ marginTop: 10, borderRadius: 16, background: `linear-gradient(120deg, ${C.orangeDeep}, ${C.orange})`, padding: 14, color: '#fff', position: 'relative', overflow: 'hidden' }}>
            <div style={{ fontSize: 10, fontWeight: 800, display: 'flex', alignItems: 'center', gap: 6, letterSpacing: '0.06em' }}><span style={{ width: 7, height: 7, borderRadius: 999, background: C.greenBright }} />LIVE SPORTS</div>
            <div style={{ fontWeight: 800, fontSize: 18, marginTop: 6 }}>Sports Arena</div>
            <div style={{ fontSize: 11, opacity: 0.92, marginTop: 2 }}>Tournaments, chess & live scores</div>
            <div style={{ marginTop: 10, display: 'inline-flex', alignItems: 'center', gap: 6, background: '#fff', color: C.orangeDeep, borderRadius: 999, padding: '7px 14px', fontWeight: 800, fontSize: 12 }}>Watch live <Icon name="arrow_forward" size={13} color={C.orangeDeep} /></div>
            <Icon name="sports_cricket" size={54} color="rgba(255,255,255,0.35)" style={{ position: 'absolute', right: 14, top: 24 }} />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 11, marginTop: 12 }}>
            {cards.map((c, i) => {
              const cp = clamp((seg(p) - 0.1) * 2.4 - i * 0.12, 0, 1);
              return (
                <div key={i} style={{ background: `linear-gradient(160deg, ${c.c}, ${C.card})`, border: `1px solid ${C.border}`, borderRadius: 16, padding: 13, minHeight: 150, display: 'flex', flexDirection: 'column', opacity: cp, transform: `translateY(${(1 - cp) * 14}px)`, position: 'relative' }}>
                  <div style={{ width: 34, height: 34, borderRadius: 10, background: c.ic, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={c.icon} size={19} color="#fff" fill={1} /></div>
                  <div style={{ fontWeight: 800, fontSize: 14, color: '#fff', marginTop: 12 }}>{c.title}</div>
                  <div style={{ fontSize: 11, color: C.text2, marginTop: 3, lineHeight: 1.3 }}>{c.sub}</div>
                  <div style={{ marginTop: 'auto', color: c.ic, fontSize: 11, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 3 }}>Open <Icon name="arrow_forward" size={12} color={c.ic} /></div>
                </div>
              );
            })}
          </div>
        </div>
      </div>
    </div>
  );
}

function SummaryScreenView({ p }) {
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <AppHeader />
      <div style={{ padding: 14 }}>
        <div style={{ borderRadius: 18, background: `linear-gradient(120deg, ${C.purple}, #0EA5A0)`, padding: 16, color: '#fff', position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', right: 14, top: 12, fontSize: 26, opacity: 0.6 }}>✦</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: 'rgba(255,255,255,0.2)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="wb_sunny" size={19} color="#fff" fill={1} /></div>
            <div style={{ fontWeight: 800, fontSize: 17 }}>Today's Summary</div>
          </div>
          <div style={{ fontSize: 12.5, lineHeight: 1.55, marginTop: 12, opacity: 0.96 }}>
            Welcome to FYC Connect! Registration is open for the Drawing competition 2026, so be sure to register today. You can also watch our live cricket tournaments, FYC Test — Village Wides and FYC LEAGUE 2026, happening right now.
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 12, fontSize: 11, fontWeight: 600, opacity: 0.9 }}><Icon name="bolt" size={14} color="#fff" fill={1} /> Updated daily</div>
        </div>
        <div style={{ marginTop: 12, background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 14 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: `linear-gradient(135deg, ${C.pink}, ${C.purpleL})`, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="calendar_month" size={18} color="#fff" fill={1} /></div>
            <div><div style={{ fontWeight: 800, fontSize: 15, color: '#fff' }}>News Digest</div><div style={{ fontSize: 11, color: C.text2 }}>The day in a glance</div></div>
          </div>
          <div style={{ fontSize: 12.5, color: '#C7CEDE', lineHeight: 1.55, marginTop: 12 }}>
            Heavy rainfall in Karnataka and Kanyakumari has boosted dam inflows, prompting the release of 15,000 cusecs of Cauvery water to Tamil Nadu.
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, marginTop: 12 }}>
            {['#Cauvery Water Release', '#Ration Card e-KYC', '#Population Census'].map((t) => (
              <div key={t} style={{ padding: '6px 12px', borderRadius: 999, border: `1px solid ${C.purpleL}66`, color: '#C4B5FD', fontSize: 11, fontWeight: 600 }}>{t}</div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function ThirukkuralScreenView({ p }) {
  const y = scrollY(p, 250);
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ transform: `translateY(${y}px)` }}>
        <AppHeader />
        <div style={{ padding: 14 }}>
          <div style={{ borderRadius: 18, background: `linear-gradient(150deg, ${C.green}, ${C.greenDeep})`, padding: 16, color: '#fff', position: 'relative', overflow: 'hidden' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div style={{ display: 'flex', gap: 10 }}>
                <div style={{ width: 34, height: 34, borderRadius: 10, background: 'rgba(255,255,255,0.15)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="menu_book" size={18} color="#fff" /></div>
                <div><div style={{ fontFamily: TAM, fontWeight: 800, fontSize: 15 }}>இன்றைய திருக்குறள்</div><div style={{ fontSize: 11, opacity: 0.85 }}>Thirukkural of the Day</div></div>
              </div>
              <div style={{ padding: '4px 10px', borderRadius: 999, border: '1px solid rgba(255,255,255,0.4)', fontFamily: TAM, fontSize: 11, fontWeight: 700 }}>குறள் #1053</div>
            </div>
            <div style={{ marginTop: 14, background: 'rgba(255,255,255,0.1)', borderRadius: 14, padding: 14, fontFamily: TAM, fontWeight: 700, fontSize: 17, lineHeight: 1.5 }}>
              கரப்பிலா நெஞ்சின் கடனறிவார் முன்நின்று இரப்புமோ ரேஎர் உடைத்து.
            </div>
            <div style={{ fontFamily: TAM, fontSize: 12.5, opacity: 0.92, marginTop: 12, lineHeight: 1.5 }}>ஒளிப்பு இல்லாத நெஞ்சும், கடைமையுணர்ச்சியும் உள்ளவரின் முன்னே நின்று இரந்து பொருள் கேட்பதும் ஓர் அழகு உடையதாகும்.</div>
            <div style={{ borderTop: '1px solid rgba(255,255,255,0.2)', marginTop: 12, paddingTop: 10, fontStyle: 'italic', fontSize: 12, opacity: 0.85, lineHeight: 1.4 }}>"The men who nought deny, but know what's due, before their face to stand as suppliants affords especial grace"</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 12, fontFamily: TAM, fontSize: 11, opacity: 0.8 }}><Icon name="auto_stories" size={13} color="#fff" /> பொருட்பால் • Wealth</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function NewsScreenView({ p }) {
  const y = scrollY(p, 120);
  const tabs = ['கன்னியாகுமரி', 'தமிழ்', 'India', 'TN Jobs', 'Central'];
  const items = [
    'Today Breaking News | Kanyakumari Updates',
    'Nagercoil Jail Death: 8 Inmates, 3 Prison Staff Arrested | News9',
    'Latest kanyakumari, Information & Updates – Health',
    'kanyakumari (@kanyakumari_today) • Instagram photos and videos',
    'kanyakumari news',
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ transform: `translateY(${y}px)` }}>
        <div style={{ padding: '14px 14px 8px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <div style={{ width: 34, height: 34, borderRadius: 10, background: '#2A1A1A', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="newspaper" size={18} color={C.orange} /></div>
            <div style={{ flex: 1, fontFamily: TAM, fontWeight: 800, fontSize: 17, color: '#fff' }}>செய்திகள் · <span style={{ fontFamily: FONT }}>News</span></div>
            <Icon name="refresh" size={18} color={C.text2} />
          </div>
          <div style={{ display: 'flex', gap: 16, marginTop: 14, borderBottom: `1px solid ${C.border}`, paddingBottom: 2 }}>
            {tabs.map((t, i) => (
              <div key={t} style={{ paddingBottom: 8, fontSize: 12, fontWeight: 700, color: i === 0 ? C.orange : C.text2, borderBottom: i === 0 ? `2px solid ${C.orange}` : '2px solid transparent', fontFamily: i < 2 ? TAM : FONT }}>{t}</div>
            ))}
          </div>
        </div>
        <div style={{ padding: '0 14px' }}>
          {items.map((t, i) => {
            const ip = clamp((seg(p) - 0.12) * 2.4 - i * 0.14, 0, 1);
            return (
              <div key={i} style={{ padding: '13px 0', borderBottom: `1px solid ${C.borderSoft}`, display: 'flex', gap: 10, opacity: ip, transform: `translateY(${(1 - ip) * 10}px)` }}>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, color: '#fff', lineHeight: 1.35 }}>{t}</div>
                  <div style={{ fontSize: 11, marginTop: 4 }}><span style={{ color: C.orange, fontWeight: 700 }}>Firecrawl</span> <span style={{ color: C.text2 }}>• now</span></div>
                </div>
                <Icon name="north_east" size={16} color={C.text2} />
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function FeedScreenView({ p }) {
  const y = scrollY(p, 120);
  const posts = [
    { when: '4d', text: 'test', likes: 0, liked: false },
    { when: '1w', text: 'Good morning', likes: 1, liked: true },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ transform: `translateY(${y}px)` }}>
        <div style={{ background: `linear-gradient(120deg, ${C.orangeDeep}, ${C.orange})`, padding: '14px 14px 16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
            <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
              <img src="assets/logos/fyc_app_icon.png" style={{ width: 30, height: 30, borderRadius: 999 }} />
              <div><div style={{ color: '#fff', fontWeight: 800, fontSize: 17 }}>Community Feed</div><div style={{ color: 'rgba(255,255,255,0.85)', fontSize: 11 }}>Stay connected. Share. Inspire.</div></div>
            </div>
            <Icon name="notifications" size={18} color="#fff" />
          </div>
          <div style={{ marginTop: 12, background: C.card, borderRadius: 14, padding: '9px 10px', display: 'flex', alignItems: 'center', gap: 9 }}>
            <div style={{ width: 26, height: 26, borderRadius: 999, background: '#3A2A12', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="person" size={16} color={C.orange} fill={1} /></div>
            <span style={{ color: C.text2, fontSize: 12, flex: 1 }}>What's happening in your community?</span>
            <div style={{ background: C.orange, color: '#fff', borderRadius: 10, padding: '6px 12px', fontSize: 12, fontWeight: 700, display: 'flex', alignItems: 'center', gap: 4 }}><Icon name="edit" size={13} color="#fff" /> Post</div>
          </div>
        </div>
        <div style={{ padding: '12px 14px 4px', display: 'flex', gap: 16, fontSize: 12, fontWeight: 700 }}>
          {[['grid_view', 'All', true], ['photo_camera', 'Instagram'], ['forum', 'Threads'], ['eco', 'Green FYC'], ['bolt', 'Activity']].map((t, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 4, color: t[2] ? C.orange : C.text2, borderBottom: t[2] ? `2px solid ${C.orange}` : 'none', paddingBottom: 6 }}><Icon name={t[0]} size={14} color={t[2] ? C.orange : C.text2} />{t[1]}</div>
          ))}
        </div>
        <div style={{ padding: '6px 14px', display: 'flex', gap: 8 }}>
          {[['grid_view', 'All', true], ['local_fire_department', 'Popular'], ['schedule', 'Recent'], ['person', 'Following']].map((c, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '7px 12px', borderRadius: 999, background: c[2] ? C.orange : C.card, color: c[2] ? '#fff' : C.text2, border: c[2] ? 'none' : `1px solid ${C.border}`, fontSize: 11, fontWeight: 700 }}><Icon name={c[0]} size={13} color={c[2] ? '#fff' : C.text2} />{c[1]}</div>
          ))}
        </div>
        <div style={{ padding: '8px 14px', display: 'flex', flexDirection: 'column', gap: 11 }}>
          {posts.map((post, i) => {
            const pp = clamp((seg(p) - 0.15) * 2.4 - i * 0.24, 0, 1);
            return (
              <div key={i} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 13, opacity: pp, transform: `translateY(${(1 - pp) * 14}px)` }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 9 }}>
                  <div style={{ width: 34, height: 34, borderRadius: 999, background: '#3A2A12', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.orange, fontWeight: 800, fontSize: 14 }}>V</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 5 }}><span style={{ color: '#fff', fontWeight: 700, fontSize: 13 }}>Varun Kumar</span><Icon name="verified" size={14} color={C.blueL} fill={1} /><span style={{ background: '#3A2A12', color: C.orange, fontSize: 9, fontWeight: 700, padding: '1px 6px', borderRadius: 5 }}>Admin</span></div>
                    <div style={{ color: C.text2, fontSize: 11, marginTop: 1 }}>{post.when} · Thread · 🌐</div>
                  </div>
                  <Icon name="more_horiz" size={18} color={C.text2} />
                </div>
                <div style={{ color: '#E7EBF6', fontSize: 14, marginTop: 11 }}>{post.text}</div>
                <div style={{ borderTop: `1px solid ${C.borderSoft}`, marginTop: 11, paddingTop: 10, display: 'flex', gap: 22, alignItems: 'center' }}>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: post.liked ? C.red : C.text2, fontSize: 12, fontWeight: 600 }}><Icon name="favorite" size={16} color={post.liked ? C.red : C.text2} fill={post.liked ? 1 : 0} />{post.likes}</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: C.text2, fontSize: 12 }}><Icon name="chat_bubble_outline" size={15} color={C.text2} />0</span>
                  <span style={{ display: 'flex', alignItems: 'center', gap: 5, color: C.text2, fontSize: 12 }}><Icon name="repeat" size={16} color={C.text2} />0</span>
                  <Icon name="send" size={16} color={C.text2} style={{ marginLeft: 'auto' }} />
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

function SportsScreenView({ p }) {
  const kb = ken(p, 1.02, 1.1);
  const rows = [
    { title: 'FYC Test — Village Wides', live: true },
    { title: 'TestA', live: false },
    { title: 'FYC LEAGUE 2026', live: true },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ padding: '14px 14px 10px', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div style={{ color: '#fff', fontWeight: 800, fontSize: 18 }}>Sports Hub</div>
        <Icon name="checklist" size={20} color="#fff" />
      </div>
      <div style={{ height: 96, overflow: 'hidden', position: 'relative' }}>
        <img src="assets/imagery/sports_cricket.png" style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${kb})` }} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(10,14,26,0.9), transparent 60%)' }} />
        <div style={{ position: 'absolute', left: 14, bottom: 8, color: '#fff', fontWeight: 800, fontSize: 15 }}>Play. Compete. Win.</div>
      </div>
      <div style={{ display: 'flex', gap: 8, padding: '12px 14px', overflow: 'hidden' }}>
        {[['military_tech', 'All', true], ['emoji_events', 'Tournaments'], ['local_fire_department', 'Weekly Games'], ['castle', 'Chess']].map((c, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '8px 12px', borderRadius: 999, background: c[2] ? C.orange : C.card, color: c[2] ? '#fff' : '#fff', border: c[2] ? 'none' : `1px solid ${C.border}`, fontSize: 11, fontWeight: 700, whiteSpace: 'nowrap' }}><Icon name={c[0]} size={14} color="#fff" />{c[1]}</div>
        ))}
      </div>
      <div style={{ padding: '2px 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {rows.map((r, i) => {
          const rp = clamp((seg(p) - 0.12) * 2.2 - i * 0.2, 0, 1);
          return (
            <div key={i} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 12, opacity: rp, transform: `translateY(${(1 - rp) * 12}px)` }}>
              <div style={{ display: 'flex', gap: 11, alignItems: 'center' }}>
                <div style={{ width: 40, height: 40, borderRadius: 12, background: '#241C10', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="sports_cricket" size={22} color={C.orange} /></div>
                <div><div style={{ color: '#fff', fontWeight: 700, fontSize: 14 }}>{r.title}</div><div style={{ display: 'flex', alignItems: 'center', gap: 5, fontSize: 11, color: C.text2, marginTop: 2 }}><Icon name="emoji_events" size={13} color={C.red} /> cricket · 2026</div></div>
              </div>
              {r.live && <div style={{ display: 'flex', alignItems: 'center', gap: 5, marginTop: 9, color: C.greenBright, fontSize: 12, fontWeight: 700 }}><Icon name="play_circle" size={15} color={C.greenBright} /> Tournament is Live</div>}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function ServeScreenView({ p }) {
  const nums = [
    { label: 'Police', n: '100', icon: 'local_police', c: C.blue },
    { label: 'Ambulance', n: '108', icon: 'emergency', c: C.red },
    { label: 'Fire', n: '101', icon: 'local_fire_department', c: C.orange },
    { label: 'Electricity', n: '1912', icon: 'bolt', c: C.orange },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT, padding: 14 }}>
      <div style={{ color: '#fff', fontWeight: 800, fontSize: 18 }}>Serve / Help</div>
      <div style={{ display: 'flex', justifyContent: 'space-around', marginTop: 16 }}>
        {[['bloodtype', 'Blood', C.red, '#3A1620'], ['warning', 'Report', C.orange, '#3A2A10'], ['volunteer_activism', 'Volunteer', C.greenBright, '#0E2A1E']].map((s, i) => (
          <div key={i} style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8 }}>
            <div style={{ width: 52, height: 52, borderRadius: 15, background: s[3], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={s[0]} size={26} color={s[2]} fill={1} /></div>
            <span style={{ color: C.text2, fontSize: 12, fontWeight: 600 }}>{s[1]}</span>
          </div>
        ))}
      </div>
      <div style={{ color: '#fff', fontWeight: 800, fontSize: 14, marginTop: 20 }}>Marketplace</div>
      {[['work', 'Jobs & Gigs', 'Find work · post a job', C.blue], ['handyman', 'Skills Directory', 'Hire local skills · offer yours', C.greenBright]].map((m, i) => (
        <div key={i} style={{ marginTop: 10, background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, padding: 13, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 40, height: 40, borderRadius: 11, background: i ? '#0E2A1E' : '#12213A', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={m[0]} size={20} color={m[3]} /></div>
          <div style={{ flex: 1 }}><div style={{ color: '#fff', fontWeight: 700, fontSize: 14 }}>{m[1]}</div><div style={{ color: C.text2, fontSize: 11, marginTop: 1 }}>{m[2]}</div></div>
          <Icon name="chevron_right" size={20} color={C.text2} />
        </div>
      ))}
      <div style={{ color: '#fff', fontWeight: 800, fontSize: 14, marginTop: 20 }}>Emergency Numbers</div>
      <div style={{ marginTop: 10, background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, overflow: 'hidden' }}>
        {nums.map((n, i) => {
          const np = clamp((seg(p) - 0.2) * 2.4 - i * 0.16, 0, 1);
          return (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 13px', borderBottom: i < 3 ? `1px solid ${C.borderSoft}` : 'none', opacity: np }}>
              <div style={{ width: 32, height: 32, borderRadius: 999, background: 'rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={n.icon} size={17} color={n.c} fill={1} /></div>
              <span style={{ flex: 1, color: '#fff', fontWeight: 600, fontSize: 15 }}>{n.label}</span>
              <span style={{ color: '#fff', fontWeight: 800, fontSize: 15 }}>{n.n}</span>
              <Icon name="call" size={17} color={n.c} fill={1} />
            </div>
          );
        })}
      </div>
    </div>
  );
}

function BloodScreenView({ p }) {
  const kb = ken(p, 1.04, 1.12);
  const chips = ['All', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  const sel = seg(p) > 0.4 ? 2 : 0;
  const donors = [
    { name: 'muhammad Shafi', loc: 'Kilimanoor', g: 'A-' },
    { name: 'Saagar Kalaam', loc: 'Kazhakuttam', g: 'A-' },
    { name: 'manesh', loc: 'Trivandrum', g: 'A-' },
    { name: 'Dorian r s', loc: 'Varkala', g: 'A-' },
  ];
  const cx = interpolate([0.28, 0.42], [70, 132], Easing.easeInOutCubic)(p);
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <BackHeader title="Blood Donation Hub" right={{ icon: 'volunteer_activism', label: 'Register' }} />
      <div style={{ height: 78, overflow: 'hidden', position: 'relative' }}>
        <img src="assets/imagery/blood_drive.png" style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${kb})` }} />
        <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(to top, rgba(10,14,26,0.85), transparent 55%)' }} />
        <div style={{ position: 'absolute', left: 14, bottom: 6, color: '#fff', fontWeight: 700, fontSize: 12 }}>Your one donation can save up to 3 lives</div>
      </div>
      <div style={{ padding: 12 }}>
        <div style={{ background: `linear-gradient(120deg, ${C.red}, #F87171)`, borderRadius: 14, padding: '11px 13px', display: 'flex', alignItems: 'center', gap: 11, boxShadow: '0 10px 24px -10px rgba(220,38,38,0.6)' }}>
          <Icon name="emergency" size={22} color="#fff" fill={1} />
          <div style={{ flex: 1 }}><div style={{ color: '#fff', fontWeight: 800, fontSize: 14 }}>Emergency Blood Needed?</div><div style={{ color: 'rgba(255,255,255,0.9)', fontSize: 10.5 }}>Tap to alert all eligible donors in your area</div></div>
          <Icon name="chevron_right" size={18} color="#fff" />
        </div>
        <div style={{ display: 'flex', gap: 7, marginTop: 12, overflow: 'hidden' }}>
          {chips.map((g, i) => {
            const on = i === sel;
            return <div key={g} style={{ padding: '7px 12px', borderRadius: 999, fontSize: 12, fontWeight: 700, background: on ? C.red : 'transparent', color: on ? '#fff' : C.red, border: `1px solid ${C.red}`, whiteSpace: 'nowrap' }}>{g}</div>;
          })}
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 9, marginTop: 12 }}>
          {donors.map((d, i) => {
            const dp = clamp((seg(p) - 0.1) * 2.4 - i * 0.16, 0, 1);
            return (
              <div key={i} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 12, display: 'flex', alignItems: 'center', gap: 11, opacity: dp, transform: `translateX(${(1 - dp) * 14}px)` }}>
                <div style={{ width: 44, height: 44, borderRadius: 999, background: '#3A1620', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.redSoft, fontWeight: 800, fontSize: 15 }}>{d.g}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ color: '#fff', fontWeight: 700, fontSize: 14 }}>{d.name}</div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 3, fontSize: 11, color: C.text2, marginTop: 2 }}><Icon name="place" size={13} color={C.text2} />{d.loc}</div>
                  <div style={{ display: 'inline-block', marginTop: 6, padding: '3px 8px', borderRadius: 6, border: `1px solid ${C.orange}66`, color: C.orange, fontSize: 10, fontWeight: 700 }}>Friends2Support</div>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 5, padding: '8px 12px', borderRadius: 10, background: '#241C10', color: C.orange, fontSize: 12, fontWeight: 700 }}><Icon name="call" size={14} color={C.orange} /> Contact</div>
              </div>
            );
          })}
        </div>
      </div>
      <Touch x={cx} y={150} press={p > 0.4 && p < 0.46 ? 1 : 0} show={seg(p)} />
    </div>
  );
}

function ReportScreenView({ p }) {
  const y = scrollY(p, 300);
  const stats = [
    { v: '2', l: 'Issues Resolved', c: C.greenBright, bg: '#0E2A1E' },
    { v: '67%', l: 'Resolution Rate', c: C.blueL, bg: '#12213A' },
    { v: '7.7 Days', l: 'Avg. Response', c: C.purpleL, bg: '#241A3A' },
    { v: '0.0K', l: 'Active Citizens', c: C.orange, bg: '#2A1E0E' },
  ];
  const cats = [
    { l: 'Road/Traffic', s: 'Potholes, Blockages, etc.', icon: 'edit_road', c: C.greenBright, on: true },
    { l: 'Power Cut', s: 'Outages, Broken wires', icon: 'bolt', c: C.orange },
    { l: 'Water', s: 'Leakages, Supply, etc.', icon: 'water_drop', c: C.blue },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <div style={{ transform: `translateY(${y}px)` }}>
        <BackHeader title="Report an Issue" sub="Help us improve Nagercoil" right={{ icon: 'list_alt', label: 'My Reports' }} />
        <div style={{ padding: '0 14px' }}>
          <div style={{ display: 'flex', gap: 8 }}>
            {stats.map((s, i) => (
              <div key={i} style={{ flex: 1, background: s.bg, border: `1px solid ${C.border}`, borderRadius: 12, padding: '11px 8px', textAlign: 'center' }}>
                <div style={{ color: s.c, fontWeight: 800, fontSize: 15 }}>{s.v}</div>
                <div style={{ color: C.text2, fontSize: 8.5, marginTop: 3 }}>{s.l}</div>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12, background: '#101E14', border: `1px solid ${C.green}44`, borderRadius: 14, padding: 14 }}>
            <div style={{ color: C.orange, fontWeight: 700, fontSize: 13 }}>Report in 3 Simple Steps</div>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 12 }}>
              {[['place', 'Auto Location\nCaptured', C.greenBright], ['mail', 'Auto Mail\nto Department', C.blueL], ['groups', 'Followed by\nFYC Team', C.purpleL]].map((s, i) => (
                <React.Fragment key={i}>
                  <div style={{ textAlign: 'center', flex: 1 }}>
                    <div style={{ width: 40, height: 40, borderRadius: 999, background: 'rgba(255,255,255,0.05)', display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto' }}><Icon name={s[0]} size={19} color={s[2]} fill={1} /></div>
                    <div style={{ color: C.text2, fontSize: 9.5, marginTop: 6, whiteSpace: 'pre-line', lineHeight: 1.3 }}>{s[1]}</div>
                  </div>
                  {i < 2 && <Icon name="chevron_right" size={16} color={C.text3} />}
                </React.Fragment>
              ))}
            </div>
          </div>
          <div style={{ marginTop: 12, background: '#FCE8E8', borderRadius: 14, padding: '12px 13px', display: 'flex', alignItems: 'center', gap: 11 }}>
            <div style={{ width: 34, height: 34, borderRadius: 999, background: '#F8CFCF', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="emergency" size={18} color={C.red} fill={1} /></div>
            <div style={{ flex: 1 }}><div style={{ color: C.red, fontWeight: 800, fontSize: 13 }}>Emergency Issue?</div><div style={{ color: '#B45454', fontSize: 10.5 }}>Report urgent hazards that need immediate attention.</div></div>
            <div style={{ width: 42, height: 24, borderRadius: 999, background: '#333', position: 'relative' }}><div style={{ position: 'absolute', left: 3, top: 3, width: 18, height: 18, borderRadius: 999, background: '#999' }} /></div>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 16 }}>
            <div style={{ color: '#fff', fontWeight: 800, fontSize: 15 }}>Select Category</div>
            <span style={{ color: C.orange, fontSize: 11, fontWeight: 700 }}>Not sure? See examples</span>
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 9, marginTop: 10 }}>
            {cats.map((c, i) => (
              <div key={i} style={{ background: c.on ? '#0E2417' : C.card, border: `2px solid ${c.on ? C.greenBright : C.border}`, borderRadius: 14, padding: '16px 8px', textAlign: 'center', boxShadow: c.on ? `0 0 16px ${C.greenBright}44` : 'none' }}>
                <Icon name={c.icon} size={24} color={c.on ? C.greenBright : c.c} fill={1} />
                <div style={{ color: c.on ? C.greenBright : '#fff', fontWeight: 700, fontSize: 12, marginTop: 8 }}>{c.l}</div>
                <div style={{ color: C.text2, fontSize: 9, marginTop: 3, lineHeight: 1.3 }}>{c.s}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

function JobsScreenView({ p }) {
  const op = seg(p);
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <BackHeader title="Jobs & Gigs" />
      <div style={{ padding: 14 }}>
        <div style={{ display: 'flex', gap: 8 }}>
          {[['All', true], ['Jobs'], ['Volunteer']].map((c, i) => (
            <div key={i} style={{ padding: '8px 16px', borderRadius: 999, background: c[1] ? C.orange : C.card, color: c[1] ? '#fff' : '#fff', border: c[1] ? 'none' : `1px solid ${C.border}`, fontSize: 12, fontWeight: 700 }}>{c[0]}</div>
          ))}
        </div>
        <div style={{ marginTop: 14, background: C.card, border: `1px solid ${C.orange}44`, borderRadius: 14, padding: 13, display: 'flex', alignItems: 'center', gap: 12 }}>
          <div style={{ width: 40, height: 40, borderRadius: 11, background: '#241C10', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="handyman" size={20} color={C.orange} /></div>
          <div style={{ flex: 1 }}><div style={{ color: '#fff', fontWeight: 700, fontSize: 14 }}>Skills Directory</div><div style={{ color: C.text2, fontSize: 11, marginTop: 1 }}>Hiring? Browse carpenters, electricians, tutors & more</div></div>
          <Icon name="chevron_right" size={20} color={C.text2} />
        </div>
        <div style={{ marginTop: 60, display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', opacity: op }}>
          <div style={{ width: 92, height: 92, borderRadius: 999, background: '#1A1A1A', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="work" size={44} color={C.orange} /></div>
          <div style={{ color: '#fff', fontWeight: 800, fontSize: 19, marginTop: 22 }}>No Jobs Yet</div>
          <div style={{ color: C.text2, fontSize: 13, marginTop: 8, maxWidth: 250 }}>Be the first to post a job or volunteer drive for the FYC community.</div>
          <div style={{ marginTop: 22, background: C.orange, color: '#fff', borderRadius: 999, padding: '11px 26px', fontWeight: 700, fontSize: 14 }}>Post a Job</div>
        </div>
      </div>
    </div>
  );
}

function EventsScreenView({ p }) {
  const kb = ken(p, 1.04, 1.12);
  const op = seg(p);
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <BackHeader title="Events" />
      <div style={{ padding: '0 14px', display: 'flex', gap: 20, fontSize: 13, fontWeight: 700, borderBottom: `1px solid ${C.border}` }}>
        {[['All', true], ['Upcoming'], ['Past'], ['My Events']].map((t, i) => (
          <div key={i} style={{ paddingBottom: 10, color: t[1] ? C.orange : C.text2, borderBottom: t[1] ? `2px solid ${C.orange}` : '2px solid transparent' }}>{t[0]}</div>
        ))}
      </div>
      <div style={{ padding: 14, opacity: op }}>
        <div style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 18, overflow: 'hidden' }}>
          <div style={{ height: 130, overflow: 'hidden', position: 'relative' }}>
            <img src="assets/imagery/events_hall.png" style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${kb})` }} />
            <div style={{ position: 'absolute', left: 12, top: 12, background: C.bg, borderRadius: 10, overflow: 'hidden', width: 46, textAlign: 'center' }}>
              <div style={{ background: C.orange, color: '#fff', fontSize: 9, fontWeight: 800, padding: '2px 0' }}>JUL</div>
              <div style={{ color: '#fff', fontWeight: 800, fontSize: 20, padding: '3px 0' }}>15</div>
            </div>
            <div style={{ position: 'absolute', right: 12, top: 12, background: C.green, color: '#fff', fontSize: 11, fontWeight: 700, padding: '4px 12px', borderRadius: 999 }}>Live</div>
          </div>
          <div style={{ padding: 14 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div style={{ color: '#fff', fontWeight: 800, fontSize: 16 }}>Drawing competition 2026</div>
              <div style={{ display: 'flex', gap: 10 }}><Icon name="group" size={16} color={C.blueL} /><Icon name="delete" size={16} color={C.red} /></div>
            </div>
            <div style={{ color: C.text2, fontSize: 12, marginTop: 6, lineHeight: 1.4 }}>Join our annual Drawing Competition 2026 and showcase your creativity. Participants of all skill levels are welcome…</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 5, color: C.text2, fontSize: 12, marginTop: 10 }}><Icon name="schedule" size={14} color={C.text2} /> 15 Jul 2026 · 10:40 AM</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 7, marginTop: 10 }}><div style={{ width: 24, height: 24, borderRadius: 999, background: C.purple, display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name="person" size={14} color="#fff" fill={1} /></div><span style={{ color: '#fff', fontSize: 12, fontWeight: 600 }}>1 Going</span></div>
            <div style={{ marginTop: 12, background: C.orangeDeep, color: '#fff', borderRadius: 12, padding: 12, textAlign: 'center', fontWeight: 800, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name="qr_code_2" size={17} color="#fff" /> Check In</div>
            <div style={{ marginTop: 10, background: C.orange, color: '#fff', borderRadius: 12, padding: 12, textAlign: 'center', fontWeight: 800, fontSize: 14 }}>Register Now</div>
          </div>
        </div>
      </div>
    </div>
  );
}

function SafetyScreenView({ p }) {
  const rise2 = (1 - clamp(interpolate([0.1, 0.4], [0, 1], Easing.easeOutCubic)(p), 0, 1)) * 100;
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT, position: 'relative' }}>
      <div style={{ opacity: 0.35, filter: 'blur(1px)' }}><HomeScreenView p={0.5} /></div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(5,7,15,0.55)' }} />
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, background: C.bg2, borderTop: `1px solid ${C.border}`, borderRadius: '22px 22px 0 0', padding: 16, transform: `translateY(${rise2}px)`, boxShadow: '0 -20px 50px rgba(0,0,0,0.6)' }}>
        <div style={{ width: 40, height: 4, borderRadius: 999, background: C.border, margin: '0 auto 14px' }} />
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Icon name="verified_user" size={24} color={C.red} fill={1} /><span style={{ color: '#fff', fontWeight: 800, fontSize: 19 }}>Safety Center</span></div>
          <Icon name="close" size={20} color={C.text2} />
        </div>
        <div style={{ color: C.text2, fontSize: 12.5, marginTop: 12, lineHeight: 1.5 }}>Alert your trusted contacts and nearby FYC members, or call the emergency number.</div>
        <div style={{ marginTop: 14, background: C.red, color: '#fff', borderRadius: 12, padding: 14, textAlign: 'center', fontWeight: 800, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, boxShadow: '0 10px 24px -8px rgba(220,38,38,0.6)' }}><Icon name="send" size={17} color="#fff" /> Send SOS to my contacts</div>
        {[['call', 'Call 112'], ['campaign', 'Alert nearby FYC members']].map((b, i) => (
          <div key={i} style={{ marginTop: 10, border: `1px solid ${C.border}`, color: '#fff', borderRadius: 12, padding: 13, textAlign: 'center', fontWeight: 700, fontSize: 14, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><Icon name={b[0]} size={16} color="#fff" /> {b[1]}</div>
        ))}
        <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 11 }}>
          {[['place', 'Share live location'], ['contact_page', 'Alert trusted contacts'], ['groups', 'Notify nearby FYC members'], ['sms', 'Works offline (SMS fallback)']].map((f, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, color: '#C7CEDE', fontSize: 13 }}><Icon name={f[0]} size={16} color={C.greenBright} fill={1} /> {f[1]}</div>
          ))}
        </div>
      </div>
    </div>
  );
}

function ProfileScreenView({ p }) {
  const shine = interpolate([0.15, 0.45], [-120, 340], Easing.easeInOutCubic)(p);
  const stats = [['event', '1', 'Events', C.purpleL], ['schedule', '0', 'Hours', C.blueL], ['bloodtype', '1', 'Donations', C.red], ['eco', '0', 'Trees', C.greenBright]];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <BackHeader title="Profile" />
      <div style={{ padding: 14 }}>
        <div style={{ background: `linear-gradient(120deg, ${C.green}, ${C.greenDeep})`, borderRadius: 18, padding: 16, display: 'flex', alignItems: 'center', gap: 14, position: 'relative', overflow: 'hidden' }}>
          <div style={{ position: 'absolute', top: 0, bottom: 0, left: shine, width: 70, background: 'linear-gradient(105deg, transparent, rgba(255,255,255,0.25), transparent)', transform: 'skewX(-18deg)' }} />
          <div style={{ width: 68, height: 68, borderRadius: 999, background: 'rgba(255,255,255,0.15)', border: '2px solid rgba(255,255,255,0.3)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontWeight: 800, fontSize: 26 }}>V</div>
          <div><div style={{ color: '#fff', fontWeight: 800, fontSize: 22 }}>Varun Kumar</div><div style={{ display: 'inline-block', marginTop: 8, padding: '5px 14px', borderRadius: 999, background: 'rgba(255,255,255,0.18)', color: '#fff', fontSize: 12, fontWeight: 600 }}>Administrator</div></div>
        </div>
        <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
          {stats.map((s, i) => {
            const sp = clamp((seg(p) - 0.1) * 2.6 - i * 0.12, 0, 1);
            return (
              <div key={i} style={{ flex: 1, background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, padding: '12px 6px', textAlign: 'center', opacity: sp, transform: `scale(${0.9 + 0.1 * sp})` }}>
                <Icon name={s[0]} size={18} color={s[3]} fill={1} />
                <div style={{ color: '#fff', fontWeight: 800, fontSize: 18, marginTop: 5 }}>{s[1]}</div>
                <div style={{ color: C.text2, fontSize: 9.5, marginTop: 1 }}>{s[2]}</div>
              </div>
            );
          })}
        </div>
        <div style={{ color: C.text2, fontSize: 12, fontWeight: 600, marginTop: 18 }}>My Activity</div>
        <div style={{ marginTop: 10, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {[['map', 'My Journey', C.pink, '#3A1428'], ['celebration', 'My Events', C.purpleL, '#241A3A'], ['search', 'My Reports', C.greenBright, '#0E2A1E'], ['badge', 'Membership Card', C.greenBright, '#0E2A1E']].map((r, i) => (
            <div key={i} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 14, padding: 12, display: 'flex', alignItems: 'center', gap: 12 }}>
              <div style={{ width: 38, height: 38, borderRadius: 11, background: r[3], display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Icon name={r[0]} size={19} color={r[2]} fill={1} /></div>
              <span style={{ flex: 1, color: '#fff', fontWeight: 600, fontSize: 15 }}>{r[1]}</span>
              <Icon name="chevron_right" size={20} color={C.text2} />
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function MembersScreenView({ p }) {
  const members = [
    { n: 'Super Administrator', i: 'S' }, { n: 'Varun Kumar', i: 'V' }, { n: 'Anish Alone', i: 'A' },
    { n: 'Nithin M', i: 'N' }, { n: 'Varun Kumar', i: 'V' }, { n: 'Varun Kumar SV', i: 'V' },
  ];
  return (
    <div style={{ height: '100%', overflow: 'hidden', background: C.bg, fontFamily: FONT }}>
      <BackHeader title="Members" />
      <div style={{ padding: '0 14px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {members.map((m, i) => {
          const mp = clamp((seg(p) - 0.1) * 2.6 - i * 0.12, 0, 1);
          return (
            <div key={i} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 16, padding: 13, display: 'flex', alignItems: 'center', gap: 12, opacity: mp, transform: `translateY(${(1 - mp) * 12}px)` }}>
              <div style={{ width: 44, height: 44, borderRadius: 999, background: '#3A2A12', display: 'flex', alignItems: 'center', justifyContent: 'center', color: C.orange, fontWeight: 800, fontSize: 16 }}>{m.i}</div>
              <span style={{ flex: 1, color: '#fff', fontWeight: 600, fontSize: 15 }}>{m.n}</span>
              <div style={{ padding: '5px 14px', borderRadius: 999, border: `1px solid ${C.red}66`, color: C.redSoft, fontSize: 12, fontWeight: 700 }}>Admin</div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ═══════════════════════ SCENES ═══════════════════════
function Intro() {
  const { progress: p } = useScene();
  const op = seg(p, 0.12, 0.88);
  const logoS = interpolate([0, 0.3], [0.6, 1], Easing.easeOutBack)(p);
  const titleUp = rise(p);
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <Backdrop />
      <div style={{ position: 'absolute', inset: 0, opacity: 0.22 }}>
        <img src="assets/imagery/hero_community.png" style={{ width: '100%', height: '100%', objectFit: 'cover', transform: `scale(${ken(p, 1.08, 1.2)})` }} />
        <div style={{ position: 'absolute', inset: 0, background: `radial-gradient(120% 120% at 50% 40%, transparent, ${C.bg} 80%)` }} />
      </div>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', opacity: op }}>
        <img src="assets/logos/fyc_app_icon.png" style={{ width: 118, height: 118, borderRadius: 30, transform: `scale(${logoS})`, boxShadow: '0 30px 70px -20px rgba(0,0,0,0.7)' }} />
        <div style={{ color: '#fff', fontFamily: FONT, fontWeight: 800, fontSize: 68, letterSpacing: '-0.03em', marginTop: 26, transform: `translateY(${titleUp}px)` }}>FYC Connect</div>
        <div style={{ color: OPTS.accent, fontFamily: TAM, fontWeight: 700, fontSize: 30, marginTop: 8, transform: `translateY(${titleUp}px)` }}>உங்கள் ஊருக்கான ஒரே செயலி</div>
        {OPTS.showEnglish && <div style={{ color: '#AEB7CE', fontFamily: FONT, fontWeight: 500, fontSize: 21, marginTop: 12 }}>One app for your whole community</div>}
      </div>
    </div>
  );
}

const featureScene = (accent, tab, sos, tamil, english, chips, View) => function () {
  const { progress: p } = useScene();
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <Backdrop />
      <Watermark opacity={seg(p)} />
      <Caption p={p} accent={accent} tamil={tamil} english={english} chips={chips} />
      <Phone p={p} activeTab={tab} sos={sos}><View p={p} /></Phone>
    </div>
  );
};

const Home = featureScene(C.orange, 'home', true, 'உங்கள் ஊர்\nஉங்கள் கையில்', 'Every community service on one home screen — blood, sports, feed, issues and more.', [{ icon: 'grid_view', label: 'Quick services' }, { icon: 'sports_cricket', label: 'Live sports' }, { icon: 'bolt', label: 'Daily updates' }], HomeScreenView);
const Summary = featureScene(C.purpleL, 'home', true, 'AI செய்தி\nசுருக்கம்', 'An AI daily summary and news digest — your whole town in a glance, updated every day.', [{ icon: 'auto_awesome', label: 'AI summary' }, { icon: 'newspaper', label: 'News digest' }, { icon: 'tag', label: 'Local topics' }], SummaryScreenView);
const Thirukkural = featureScene(C.greenBright, 'home', true, 'இன்றைய\nதிருக்குறள்', 'A Thirukkural every day — with meaning and translation, keeping our culture alive.', [{ icon: 'menu_book', label: 'Daily Kural' }, { icon: 'translate', label: 'Meaning + English' }, { icon: 'favorite', label: 'Our heritage' }], ThirukkuralScreenView);
const News = featureScene(C.orange, 'home', true, 'உள்ளூர்\nசெய்திகள்', 'Local Kanyakumari and Tamil Nadu news, gathered live — stay informed in your language.', [{ icon: 'newspaper', label: 'Local news' }, { icon: 'public', label: 'TN & India' }, { icon: 'work', label: 'TN jobs' }], NewsScreenView);
const Feed = featureScene(C.orange, 'feed', true, 'சமூக\nஊட்டம்', 'Share updates, photos and threads — stay connected with your whole community.', [{ icon: 'dynamic_feed', label: 'Threads' }, { icon: 'photo_camera', label: 'Gallery' }, { icon: 'favorite', label: 'React & reply' }], FeedScreenView);
const Sports = featureScene(C.orange, 'play', true, 'விளையாட்டு\nமையம்', 'Cricket leagues, weekly games and chess — join teams and follow live tournaments.', [{ icon: 'sports_cricket', label: 'Cricket' }, { icon: 'castle', label: 'Chess' }, { icon: 'emoji_events', label: 'Live scores' }], SportsScreenView);
const Serve = featureScene(C.greenBright, 'serve', true, 'சேவை /\nஉதவி', 'Volunteer, hire local skills, and reach every emergency number in one tap.', [{ icon: 'volunteer_activism', label: 'Volunteer' }, { icon: 'handyman', label: 'Skills' }, { icon: 'emergency', label: 'Helplines' }], ServeScreenView);
const Blood = featureScene(C.red, 'serve', true, 'ரத்த\nதானம்', 'Find verified donors near you by blood group — or raise an emergency alert instantly.', [{ icon: 'bloodtype', label: 'Find by group' }, { icon: 'emergency', label: 'Emergency alert' }, { icon: 'call', label: 'Contact donors' }], BloodScreenView);
const Issue = featureScene(C.greenBright, 'serve', true, 'ஊர் பிரச்சனை\nபுகார்', 'Report roads, power or water problems — auto-location and mailed straight to the department.', [{ icon: 'edit_road', label: 'Roads' }, { icon: 'bolt', label: 'Power' }, { icon: 'water_drop', label: 'Water' }], ReportScreenView);
const Jobs = featureScene(C.orange, 'serve', true, 'வேலை &\nபணிகள்', 'Find work, post jobs and volunteer drives — a marketplace for the whole community.', [{ icon: 'work', label: 'Find work' }, { icon: 'post_add', label: 'Post a job' }, { icon: 'handyman', label: 'Skills directory' }], JobsScreenView);
const Events = featureScene(C.orange, 'home', true, 'சமூக\nநிகழ்வுகள்', 'Festivals, competitions and meetings — register and check in with a QR code.', [{ icon: 'event', label: 'Register' }, { icon: 'qr_code_2', label: 'QR check-in' }, { icon: 'celebration', label: 'Festivals' }], EventsScreenView);
const Safety = featureScene(C.sos, 'home', false, 'அவசர\nSOS பாதுகாப்பு', 'One tap alerts your contacts and nearby members, shares your location — even works offline.', [{ icon: 'send', label: 'Alert contacts' }, { icon: 'my_location', label: 'Live location' }, { icon: 'sms', label: 'Works offline' }], SafetyScreenView);
const Profile = featureScene(C.greenBright, 'home', true, 'உங்கள்\nசுயவிவரம்', 'Your profile, digital membership card, activity and the full club member directory.', [{ icon: 'badge', label: 'Digital card' }, { icon: 'insights', label: 'My activity' }, { icon: 'groups', label: 'Members' }], ProfileScreenView);
const Members = featureScene(C.orange, 'home', true, 'உறுப்பினர்\nஇயக்ககம்', 'The full FYC member directory — find admins and members across your community.', [{ icon: 'groups', label: 'Directory' }, { icon: 'admin_panel_settings', label: 'Admins' }, { icon: 'search', label: 'Find members' }], MembersScreenView);

function Closing() {
  const { progress: p } = useScene();
  const op = seg(p, 0.12, 0.9);
  const logoS = interpolate([0, 0.28], [0.7, 1], Easing.easeOutBack)(p);
  const up = rise(p);
  const photos = ['hero_community', 'blood_drive', 'impact_sapling', 'beach_clean', 'sports_cricket'];
  const pan = interpolate([0, 1], [0, -60], Easing.linear)(p);
  return (
    <div style={{ position: 'absolute', inset: 0, overflow: 'hidden' }}>
      <Backdrop />
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 150, opacity: 0.26 * op }}>
        <div style={{ display: 'flex', gap: 12, transform: `translateX(${pan}px)`, height: '100%', padding: 12 }}>
          {photos.concat(photos).map((n, i) => <img key={i} src={`assets/imagery/${n}.png`} style={{ height: '100%', width: 230, objectFit: 'cover', borderRadius: 14, flexShrink: 0 }} />)}
        </div>
        <div style={{ position: 'absolute', inset: 0, background: `linear-gradient(to top, ${C.bg}, transparent)` }} />
      </div>
      <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', paddingBottom: 60, opacity: op }}>
        <img src="assets/logos/fyc_app_icon.png" style={{ width: 96, height: 96, borderRadius: 26, transform: `scale(${logoS})`, boxShadow: '0 24px 60px -18px rgba(0,0,0,0.7)' }} />
        <div style={{ color: '#fff', fontFamily: TAM, fontWeight: 800, fontSize: 52, marginTop: 22, transform: `translateY(${up}px)`, textAlign: 'center' }}>இன்றே பதிவிறக்கம் செய்யுங்கள்</div>
        <div style={{ color: OPTS.accent, fontFamily: FONT, fontWeight: 700, fontSize: 27, marginTop: 10, transform: `translateY(${up}px)` }}>Download &amp; join FYC Connect</div>
        <div style={{ display: 'flex', gap: 14, marginTop: 28 }}>
          {[{ i: 'shop', a: 'GET IT ON', b: 'Google Play' }, { i: 'phone_iphone', a: 'DOWNLOAD ON THE', b: 'App Store' }].map((s, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 20px', borderRadius: 14, background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.16)' }}>
              <Icon name={s.i} size={26} color="#fff" />
              <div style={{ textAlign: 'left', lineHeight: 1.15 }}><div style={{ color: '#AEB7CE', fontFamily: FONT, fontSize: 10, fontWeight: 600, letterSpacing: '0.06em' }}>{s.a}</div><div style={{ color: '#fff', fontFamily: FONT, fontSize: 17, fontWeight: 800 }}>{s.b}</div></div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function FYCLaunch(props) {
  OPTS.accent = props.accent || C.orange;
  OPTS.showEnglish = String(props.showEnglish) !== 'false';
  return (
    <window.SceneStage width={1280} height={720} bg={C.bg} scenes={window.OM_SCENES} playback={window.OM_PLAYBACK}>
      {{ Intro, Home, Summary, Thirukkural, News, Feed, Sports, Serve, Blood, Issue, Jobs, Events, Safety, Profile, Members, Closing }}
    </window.SceneStage>
  );
}

window.FYCLaunch = FYCLaunch;
module.exports = { FYCLaunch };
