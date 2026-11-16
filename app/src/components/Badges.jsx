import { useProgress } from '../lib/store.jsx'
import { badgeDefs, levelFor, xpForLevel } from '../lib/game.js'

export default function Badges({ cert }) {
  const { progress } = useProgress()
  const lvl = levelFor(progress.xp, cert.levelTitles)
  const defs = badgeDefs(cert)
  const earned = defs.filter((b) => progress.badges[b.id]).length
  return (
    <div className="grid">
      <section className="card span2 center">
        <div className="big-emoji">⭐</div>
        <h2>Level {lvl.level} — {lvl.title}</h2>
        <div className="track"><div className="fill" style={{ width: `${(lvl.into / lvl.span) * 100}%` }} /></div>
        <p className="hint">{progress.xp} XP · {xpForLevel(lvl.level + 1) - progress.xp} XP to level {lvl.level + 1}</p>
      </section>
      <section className="card span2">
        <h3>Badges {earned}/{defs.length}</h3>
        <div className="badge-grid">
          {defs.map((b) => (
            <div key={b.id} className={`badge ${progress.badges[b.id] ? 'earned' : ''}`} title={b.desc}>
              <span className="badge-icon">{b.icon}</span>
              <b>{b.name}</b>
              <small>{b.desc}</small>
            </div>
          ))}
        </div>
      </section>
    </div>
  )
}
