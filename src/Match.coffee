@WebActors ?= {}

match = (pattern, value, captured) ->
  if pattern is value
    captured
  else
    null

WebActors.match = (pattern, value) ->
  match pattern, value, []
