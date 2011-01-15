ANY = WebActors.ANY

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
        WebActors.receive WebActors.ANY, (reply_id) ->
          WebActors.send reply_id, "it works!"

      WebActors.send worker_id, WebActors.self()

      WebActors.receive ANY, (result) ->
        expect(result).toEqual("it works!")
        done = true

    waitsFor -> done

describe "WebActor.spawnLinkedWorker", ->
  it "should spawn a worker linked to the current one", ->
    passed = false

    WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) -> ["exit", killer_id, reason]
      worker_id = spawn_helper 'spawnLinkedWorker', ->
      WebActors.receive ["exit", worker_id, ANY], (message) ->
        passed = true

    waitsFor -> passed

describe "WebActors Workers", ->
  it "should successfully receive messages with arrays in them", ->
    passed = false

    WebActors.spawn ->
      worker_id = spawn_helper 'spawnWorker', ->
        WebActors.receive [WebActors.ANY], (m) ->
          reply_id = m[0]
          WebActors.send reply_id, "it works!"

      WebActors.send worker_id, [WebActors.self()]

      WebActors.receive "it works!", ->
        passed = true

    waitsFor -> passed

describe "WebActors.terminateWorker", ->
  it "should forcibly kill an idle worker", ->
    passed = false

    WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) -> [killer_id, reason]
      worker_id = spawn_helper 'spawnLinkedWorker', ->
        # render unkillable through normal means
        WebActors.trapKill ->
        WebActors.receive "beef", ->
      WebActors.terminateWorker worker_id
      WebActors.receive [worker_id, ANY], ->
        passed = true

    waitsFor -> passed

  xit "should forcibly kill a worker stuck in a loop", ->
    passed = false

    WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) -> [killer_id, reason]
      worker_id = spawn_helper 'spawnLinkedWorker', ->
        null while true
      WebActors.terminateWorker worker_id
      WebActors.receive [worker_id, ANY], ->
        passed = true

    waitsFor -> passed

  it "should properly kill other actors in the worker too", ->
    passed = false

    WebActors.spawn ->
      WebActors.trapKill (killer_id, reason) -> [killer_id, reason]

      worker_id = spawn_helper 'spawnWorker', ->
        WebActors.receive WebActors.ANY, (parent_id) ->
          WebActors.spawn ->
            WebActors.send parent_id, WebActors.self()
            WebActors.receive "ready", ->
              WebActors.send parent_id, "go"
              WebActors.receive "beef", ->
          WebActors.receive "beef", ->

      WebActors.send worker_id, WebActors.self()

      WebActors.receive ANY, (grandchild_id) ->
        WebActors.link grandchild_id
        WebActors.send grandchild_id, "ready"
        WebActors.receive "go", ->
          WebActors.terminateWorker worker_id
          WebActors.receive [grandchild_id, ANY], ->
            passed = true

    waitsFor -> passed
