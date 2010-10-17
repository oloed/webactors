describe "A WebActors Actor", ->
  $$ = WebActors.$$

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
    received = null

    actor_id = WebActors.spawn ->
      WebActors.receive [$$, (m) -> received = m]

    WebActors.send actor_id, expected

    waitsFor -> received is expected
