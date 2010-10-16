describe "WebActors.match", ->
  it "should reject non-matches", ->
    expect(WebActors.match(true, false)).toEqual null

  it "should match exact numbers", ->
    expect(WebActors.match(3, 3)).toEqual []

  it "should match exact strings", ->
    expect(WebActors.match("foobar", "foobar")).toEqual []

  it "should match exact booleans", ->
    for b in [true, false]
      expect(WebActors.match(b, b)).toEqual []
