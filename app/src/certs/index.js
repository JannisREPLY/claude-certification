const modules = import.meta.glob('./*/content.json', { eager: true, import: 'default' })
const labModules = import.meta.glob('../../lab/labs/*/lab.json', { eager: true, import: 'default' })
const labs = Object.values(labModules).sort((a, b) => (a.domain + a.objectives[0] + a.id).localeCompare(b.domain + b.objectives[0] + b.id))

export const certs = Object.values(modules)
  .map((c) => ({ ...c, labs: labs.filter((l) => l.cert === c.id && !l.mock), mockLabs: labs.filter((l) => l.cert === c.id && l.mock) }))
  .sort((a, b) => a.title.localeCompare(b.title))
