importScripts("../lib/webactors.js")

WebActors.initWorker ->
  WebActors.receive WebActors.$ARG, (body_source) ->
    body = eval(body_source)
    body.apply(this)
