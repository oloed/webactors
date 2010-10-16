@WebActors ?= {}

class Mailbox
  constructor: ->
    @messages = []
    @consumers = []

  postMessage: (message) ->
    for i in [0...@consumers.length]
      consumer = @consumers[i]
      cont = consumer message
      if cont
        @consumers.splice(i, 1)
        # avoid reentrancy
        setTimeout(cont, 0)
        return undefined
    @messages.push message
    undefined

  consumeOnce: (consumer) ->
    for i in [0...@messages.length]
      message = @messages[i]
      cont = consumer message
      if cont
        @messages.splice(i, 1)
        # avoid reentrancy
        setTimeout(cont, 0)
        return undefined
    @consumers.push consumer
    undefined

WebActors.Mailbox = Mailbox
