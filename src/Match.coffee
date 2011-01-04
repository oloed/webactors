WebActors = if require? and exports?
              exports
            else
              @WebActors ?= {}

class CapturingPattern
  constructor: (@body) ->
  
  match: (value, captured) ->
    captured = match(@body, value, captured)
    captured.push value if captured
    return captured

$ARG = (body) ->
  new CapturingPattern(body)

ANY = ->

empty_func = ->

is_array = (value) ->
  return true if value instanceof Array
  if typeof(value) is "object"
    # fallback necessary for arrays passed to workers (in Chrome)
    try
      empty_func.apply(this, value)
      true
    catch e
      false
  else
    false

match = (pattern, value, captured) ->
  if typeof(pattern) is "object"
    if pattern instanceof Array
      return null unless is_array(value)
      pattern_length = pattern.length
      return null unless value.length is pattern_length
      for i in [0...pattern_length]
        captured = match(pattern[i], value[i], captured)
        break if captured is null
    else if pattern instanceof CapturingPattern
      captured = pattern.match(value, captured)
    else
      return null if typeof(value) is not "object"
      for name of pattern
        captured = match(pattern[name], value[name], captured)
        break if captured is null
  else if pattern is $ARG
    # match anything and capture
    captured.push value
  else if pattern is ANY
    jasmine.log(value)
    # match anything
  else
    return null unless pattern is value
  return captured

WebActors.match = (pattern, value) ->
  match pattern, value, []

WebActors.$ARG = $ARG
WebActors.ANY = ANY
