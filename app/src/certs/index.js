const modules = import.meta.glob('./*/content.json', { eager: true, import: 'default' })
const labModules = import.meta.env.VITE_NO_LABS ? {} : import.meta.glob('../../lab/labs/*/lab.json', { eager: true, import: 'default' })
const labs = Object.values(labModules).sort((a, b) => (a.domain + a.objectives[0]).localeCompare(b.domain + b.objectives[0]))

export const certs = Object.values(modules)
  .map((c) => ({ ...c, labs: labs.filter((l) => l.cert === c.id) }))
  .sort((a, b) => a.title.localeCompare(b.title))
