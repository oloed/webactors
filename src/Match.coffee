@WebActors ?= {}

match = (pattern, value, captured) ->
  if typeof(pattern) is "object"
    if pattern instanceof Array
      return null unless value instanceof Array
      pattern_length = pattern.length
      return null unless value.length is pattern_length
      for i in [0...pattern_length]
        captured = match(pattern[i], value[i], captured)
        break if captured is null
    else
      return null if typeof(value) is not "object"
      for name of pattern
        captured = match(pattern[name], value[name], captured)
        break if captured is null
  else
    return null unless pattern is value
  return captured

@WebActors.match = (pattern, value) ->
  match pattern, value, []
