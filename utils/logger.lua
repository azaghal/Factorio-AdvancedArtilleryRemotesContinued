
global.messages = global.messages or {}

local LOG_INFO   = ""
local LOG_WARN   = " [color=125,125,0](warning)[/color] "
local LOG_ERROR  = " [color=125,0,0](error)[/color] "
local LOG_ASSERT = " [color=125,0,0](assert)[/color] "
local LOG_DEBUG  = " [color=0,125,0](debug)[/color] "
local suppress_log = false

local function _print(message, log_level)
  if suppress_log == true then return end

  local prefix = MOD_TOKEN .. ": " .. (log_level or "")
  local suffix = ""

  if type(message) == "table" then
    message = {"", prefix, message}
  else
    message = prefix .. message
  end

  game.print(message)
end

_info  = _print
_warn  = function(message) _print(message, LOG_WARN) end
_error = function(message) _print(message, LOG_ERROR) end

_debug = function(message) end
if not MOD_RELEASE then
  _debug = function(message)
    _print(message, LOG_DEBUG)
  end
end

_assert = function(testcase, message) end
if not MOD_RELEASE then
  _assert = function(testcase, message)
    if testcase then return end
    _print(message, LOG_ASSERT)
  end
end

function toggle_log(event)
  suppress_log = not suppress_log
end
