@WebActors ?= {}

class Router
  constructor: ->
    @default_gateway = (node, message) ->
    @gateways = {}

  route_message: (node, message) ->
    gateway = @gateways[node] or @default_gateway
    gateway(node, message)
    undefined

  register_gateway: (node, callback) ->
    @gateways[node] = callback
    undefined

  unregister_gateway: (node) ->
    delete @gateways[node]
    undefined

  set_default_gateway: (callback) ->
    @default_gateway = callback

@WebActors.Router = Router
