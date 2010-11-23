@WebActors ?= {}

class CapturingPattern
  constructor: (@body) ->
  
  match: (value, captured) ->
    captured = match(@body, value, captured)
    captured.push value if captured
    return captured

capture = (body) ->
  new CapturingPattern(body)

any = "oijwfeiojiowejfiowjfi"

match = (pattern, value, captured) ->
  if typeof(pattern) is "object"
    if pattern instanceof Array
      return null unless value instanceof Array
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
  else if pattern is capture
    # match anything and capture
    captured.push value
  else if pattern is any
    jasmine.log(value)
    # match anything
  else
    return null unless pattern is value
  return captured

@WebActors.match = (pattern, value) ->
  match pattern, value, []

@WebActors.capture = capture
@WebActors.$$ = capture

@WebActors.any = any
@WebActors.$_ = any
