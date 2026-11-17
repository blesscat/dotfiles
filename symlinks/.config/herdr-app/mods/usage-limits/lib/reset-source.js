import { appHome, exec, readTextFile } from 'herdr'

const NODE_RUNNER = `from pathlib import Path
import json,shutil,subprocess,sys
pinned=Path.home()/'.nvm/versions/node/v24.14.0/bin/node'
node=str(pinned) if pinned.is_file() else shutil.which('node')
try:
 if not node: raise ValueError()
 result=subprocess.run([node,'-e',sys.argv[1],'--',sys.argv[2],sys.argv[3]],capture_output=True,text=True,timeout=25)
 data=json.loads(result.stdout)
 print(json.dumps(data,separators=(',',':')))
except Exception:
 print('{"state":"error","code":"request_failed"}')`

export async function resetRequest(provider, action, payload = {}, machine = null) {
  if (!['status', 'consume'].includes(action)) return { state: 'error', code: 'invalid_action' }
  const folder = `${appHome()}/mods/usage-limits/helpers`
  try {
    let reply
    if (provider === 'codex') {
      const script = await readTextFile(`${folder}/codex-reset.py`)
      if (!script) return { state: 'error', code: 'not_installed' }
      reply = await exec('python3', ['-c', script, action, JSON.stringify(payload)], {
        timeout: 35000,
      })
    } else if (provider === 'zcode') {
      const script = await readTextFile(`${folder}/zcode-usage.cjs`)
      if (!script) return { state: 'error', code: 'not_installed' }
      const mode = action === 'status' ? '--reset-status' : '--reset-use'
      const options = { timeout: 30000 }
      if (machine && machine !== 'local') options.on = machine
      reply = await exec(
        'python3',
        ['-c', NODE_RUNNER, script, mode, JSON.stringify(payload)],
        options,
      )
    } else return { state: 'error', code: 'unsupported_provider' }
    const data = JSON.parse(reply.stdout)
    if (['ready', 'complete', 'error'].includes(data?.state)) return data
  } catch {
    // No provider error bodies or credentials enter the card.
  }
  return { state: 'error', code: 'request_failed' }
}
