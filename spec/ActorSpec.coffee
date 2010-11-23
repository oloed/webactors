describe "A WebActors Actor", ->
  $$ = WebActors.$$
  $_ = WebActors.$_

  it "should have a unique ID", ->
    actor_id_a = WebActors.spawn ->
    actor_id_b = WebActors.spawn ->
    expect(actor_id_a).not.toEqual(actor_id_b)

  it "should be able to access its own ID", ->
    got_id = null

    actor_id = WebActors.spawn ->
      got_id = WebActors.get_self()
      
    waitsFor -> got_id is actor_id

  it "should receive messages", ->
    expected = "foobar"
    received = []

    actor_id = WebActors.spawn ->
      WebActors.receive $$, (m) -> received.push(m)

    WebActors.send actor_id, expected

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([expected])

  it "should treat multiple receives as alternatives", ->
    received = []

    actor_id = WebActors.spawn ->
      WebActors.receive $$("foo"), (m) ->
        received.push(m)
        WebActors.receive $$("baz"), (m) ->
          received.push(m)
      WebActors.receive $$("bar"), (m) ->
        received.push(m)
        WebActors.receive $$("baz"), (m) ->
          received.push(m)

    WebActors.send actor_id, "bar"
    WebActors.send actor_id, "foo"
    WebActors.send actor_id, "baz"

    waitsFor -> received.length >= 2

    runs -> expect(received).toEqual(["bar", "baz"])

  it "should have shorthand for sending to self", ->
    completed = false

    WebActors.spawn ->
      WebActors.send_self "foo"
      WebActors.receive "foo", -> completed = true
    
    waitsFor -> completed

  it "should support exit notification", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trap_exit (exited, reason) -> [exited, reason]

      WebActors.receive $$, (m) ->
        received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.send_exit actor_a_id, "foobar"

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, "foobar"]])

  it "should send exit notifications when linked actors exit normally", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trap_exit (exited, reason) -> [exited, reason]

      WebActors.receive $$, (m) ->
        received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.link actor_a_id

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, null]])

  it "should propagate exit notifications across linked actors", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.trap_exit (exited, reason) -> [exited, reason]
      WebActors.receive $$, (m) -> received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.link actor_a_id
      WebActors.receive $_, ->

    actor_c_id = WebActors.spawn ->
      WebActors.send_exit actor_b_id, "foobar"

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual([[actor_b_id, "foobar"]])

  it "should kill actors receiving untrapped exit notifications", ->
    received = []

    actor_a_id = WebActors.spawn ->
      WebActors.receive $$, (m) -> received.push m

    actor_b_id = WebActors.spawn ->
      WebActors.send_exit actor_a_id, "foobar"
      WebActors.send actor_a_id, "baz"

    setTimeout((-> received.push "watchdog"), 100)

    waitsFor -> received.length >= 1

    runs -> expect(received).toEqual(["watchdog"])
