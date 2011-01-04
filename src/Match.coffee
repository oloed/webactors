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

match = (pattern, value) ->
  if typeof(pattern) is "object"
    if pattern is null
      value is null
    else if is_array(pattern)
      return false unless is_array(value)
      pattern_length = pattern.length
      return false unless value.length is pattern_length
      for i in [0...pattern_length]
        matched = match(pattern[i], value[i])
        return false unless matched
      true
    else
      return null if typeof(value) is not "object"
      for name of pattern
        matched = match(pattern[name], value[name])
        return false unless matched
      true
  else if pattern is ANY
    # match anything
    true
  else
    pattern is value

WebActors.match = match

WebActors.ANY = ANY
