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
    else if pattern is null
      return null unless value is null
    else if pattern instanceof CapturingPattern
      captured = pattern.match(value, captured)
    else
      # punt on doing general matching on objects for now
      return null
  else if pattern is $ARG
    # match anything and capture
    captured.push value
  else if pattern is ANY
    # match anything, do nothing else
  else if pattern isnt value
    # fail match
    return null
  return captured

WebActors.match = (pattern, value) ->
  match pattern, value, []

WebActors.$ARG = $ARG
WebActors.ANY = ANY
