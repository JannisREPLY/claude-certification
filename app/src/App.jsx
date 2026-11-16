import { useState } from 'react'
import { certs } from './certs/index.js'
import { ProgressProvider, useProgress } from './lib/store.jsx'
import { levelFor, currentStreak } from './lib/game.js'
import { readiness } from './lib/readiness.js'
import ReadinessBar from './components/ReadinessBar.jsx'
import Dashboard from './components/Dashboard.jsx'
import Learn from './components/Learn.jsx'
import Practice from './components/Practice.jsx'
import MockExam from './components/MockExam.jsx'
import Badges from './components/Badges.jsx'
import Lab from './components/Lab.jsx'
import CertPicker from './components/CertPicker.jsx'

const TABS = [
  ['dashboard', '🏠', 'Dashboard'],
  ['learn', '📚', 'Learn'],
  ['practice', '🎯', 'Practice'],
  ['lab', '🧪', 'Lab'],
  ['exam', '📝', 'Mock Exam'],
  ['badges', '🏆', 'Badges'],
]

export default function App() {
  const [certId, setCertId] = useState(certs.length === 1 ? certs[0].id : null)
  const cert = certs.find((c) => c.id === certId)
  if (!cert) return <CertPicker onPick={setCertId} />
  return (
    <ProgressProvider cert={cert}>
      <Shell cert={cert} onBack={certs.length > 1 ? () => setCertId(null) : null} />
    </ProgressProvider>
  )
}

function Shell({ cert, onBack }) {
  const { progress, toasts } = useProgress()
  const [tab, setTab] = useState('dashboard')
  const [launch, setLaunch] = useState(null)
  const lvl = levelFor(progress.xp, cert.levelTitles)
  const r = readiness(cert, progress)
  const go = (t, opts = null) => {
    setLaunch(opts)
    setTab(t)
    window.scrollTo(0, 0)
  }

  return (
    <div className={`app ${tab === 'lab' ? 'wide' : ''}`}>
      <header className="topbar">
        <div className="brand">
          <span className="logo">🎓</span>
          {onBack && <button className="btn tiny" onClick={onBack} title="All certifications">← All</button>}
          <span className="cert-title">{cert.title}</span>
        </div>
        <div className="stats">
          <span className="pill" title="Daily streak">🔥 {currentStreak(progress)}</span>
          <span className="pill" title={`${lvl.into}/${lvl.span} XP to next level`}>
            ⭐ Lv {lvl.level}
            <span className="mini-bar"><span style={{ width: `${(lvl.into / lvl.span) * 100}%` }} /></span>
          </span>
          <span className="pill">💰 {progress.xp} XP</span>
        </div>
      </header>
      <ReadinessBar r={r} exam={cert.exam} compact onClick={() => go('dashboard')} />
      <nav className="tabs">
        {TABS.filter(([id]) => id !== 'lab' || cert.labs.length).map(([id, icon, label]) => (
          <button key={id} className={tab === id ? 'active' : ''} onClick={() => go(id)}>
            <span>{icon}</span> {label}
          </button>
        ))}
      </nav>
      <main>
        {tab === 'dashboard' && <Dashboard cert={cert} r={r} go={go} />}
        {tab === 'learn' && <Learn cert={cert} go={go} initial={launch} />}
        {tab === 'practice' && <Practice key={JSON.stringify(launch)} cert={cert} launch={launch} />}
        {tab === 'lab' && <Lab cert={cert} />}
        {tab === 'exam' && <MockExam cert={cert} />}
        {tab === 'badges' && <Badges cert={cert} />}
      </main>
      <div className="toasts">
        {toasts.map((t) => <div key={t.id} className="toast"><span>{t.icon}</span> {t.text}</div>)}
      </div>
    </div>
  )
}
