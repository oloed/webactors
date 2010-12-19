@WebActors ?= {}

class Router
  constructor: ->
    @default_gateway = (actor_id, verb, param) ->
    @gateways = {}

  route_message: (actor_id, verb, param) ->
    gateway = null
    prefix = actor_id
    until (separator_index = prefix.lastIndexOf(":")) is -1
      prefix = actor_id.substr(0, separator_index)
      gateway = @gateways[prefix]
      break if gateway
    gateway = gateway or @default_gateway
    gateway(actor_id, verb, param)
    undefined

  register_gateway: (prefix, callback) ->
    @gateways[prefix] = callback
    undefined

  unregister_gateway: (prefix) ->
    delete @gateways[prefix]
    undefined

  set_default_gateway: (callback) ->
    @default_gateway = callback
    undefined

@WebActors.Router = Router
