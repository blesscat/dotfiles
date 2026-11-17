import { appHome, exec, machines, readTextFile } from 'herdr'
import { sampleReport, selectSample } from '../providers/extra.js'

// One batch for all requested extra providers, shared by concurrent fetches.
export class ExtraSource {
  constructor() {
    this.pending = null
    this.startedAt = 0
    this.key = ''
  }

  async read(ids) {
    const key = [...ids].sort().join(',')
    if (this.pending && this.key === key && Date.now() - this.startedAt < 5000) {
      return this.pending
    }
    this.key = key
    this.startedAt = Date.now()
    this.pending = this.collect(key)
    return this.pending
  }

  async collect(ids) {
    const folder = `${appHome()}/mods/usage-limits/helpers`
    const [script, zcode] = await Promise.all([
      readTextFile(`${folder}/five-usage.py`),
      readTextFile(`${folder}/zcode-usage.cjs`),
    ])
    const samples = {}
    if (script && zcode) {
      const ready = (machines() ?? []).filter(
        (machine) => machine.name && machine.layout === 'ready',
      )
      const names = ['local', ...ready.map((machine) => machine.name)]
      await Promise.all(
        names.map(async (machine) => {
          const options = { timeout: 16000 }
          if (machine !== 'local') options.on = machine
          try {
            const reply = await exec('python3', ['-c', script, zcode, ids], options)
            const sample = JSON.parse(reply.stdout)
            if (sample.providers) samples[machine] = sample
          } catch {
            // Provider state retains its last good sample, with its original timestamp.
          }
        }),
      )
    }
    const now = Math.floor(Date.now() / 1000)
    return Object.fromEntries(
      ids.split(',').map((id) => [id, sampleReport(selectSample(samples, id), now)]),
    )
  }
}
