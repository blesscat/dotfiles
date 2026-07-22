hs.autoLaunch(true)

local inputSource = require("input_source")
local helixInputSource = require("helix_input_source")

inputSource.start()
helixInputSource.start({
  keepEnglish = inputSource.keepEnglish,
  useInputSource = inputSource.use,
  sourceToPreserve = inputSource.sourceToPreserve,
})
