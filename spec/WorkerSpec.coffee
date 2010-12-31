spawn_helper = (method, body) ->
  actor_id = WebActors[method]("spec/WorkerSpecStub.js")
  body_string = "(#{body})"
  WebActors.send actor_id, body_string
  actor_id

describe "WebActors.spawnWorker", ->
  it "should spawn a functioning actor", ->
    done = false

    WebActors.spawn ->
      worker_id = spawn_helper 'spawnWorker', ->
        WebActors.receive WebActors.$VAR, (reply_id) ->
          WebActors.send reply_id, "it works!"

      WebActors.send worker_id, WebActors.self()

      WebActors.receive WebActors.$VAR, (result) ->
        expect(result).toEqual("it works!")
        done = true

    waitsFor -> done
