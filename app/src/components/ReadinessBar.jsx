export default function ReadinessBar({ r, exam, compact, onClick }) {
  const done = r.checks.filter((c) => c.ok).length
  const state = r.ready ? 'ready' : r.checks[0].ok ? 'close' : 'notyet'
  const label = r.ready ? '✅ Exam ready!' : `${done}/${r.checks.length} readiness checks`
  return (
    <div className={`readiness ${state} ${compact ? 'compact' : ''}`} onClick={onClick} role={onClick ? 'button' : undefined}>
      <div className="readiness-head">
        <strong>Exam readiness</strong>
        <span><b>{r.percent}%</b> · pass at {r.passPercent}% · {label}</span>
      </div>
      <div className="track">
        <div className="fill" style={{ width: `${r.percent}%` }} />
        <div className="marker" style={{ left: `${r.passPercent}%` }} title={`Pass at ${r.passPercent}%`} />
      </div>
      {!compact && (
        <ul className="checks">
          {r.checks.map((c) => <li key={c.id} className={c.ok ? 'ok' : ''}>{c.ok ? '✅' : '⬜'} {c.label}</li>)}
        </ul>
      )}
    </div>
  )
}
