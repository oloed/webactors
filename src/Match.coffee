WebActors = if require? and exports?
              exports
            else
              @WebActors ?= {}

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
        matched = match(pattern[i], value[i], captured)
        return false unless matched
    else
      return null if typeof(value) is not "object"
      for name of pattern
        matched = match(pattern[name], value[name], captured)
        return false unless matched
  else if pattern is ANY
    # match anything
    return true
  else
    return pattern is value

WebActors.match = (pattern, value) ->
  match pattern, value, []

WebActors.ANY = ANY
