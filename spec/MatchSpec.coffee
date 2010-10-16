describe "WebActors.match", ->
  it "should exactly match numbers", ->
    expect(WebActors.match(3, 2)).toEqual null
    expect(WebActors.match(3, 3)).toEqual []

  it "should exactly match strings", ->
    expect(WebActors.match("foobar", "barfoo")).toEqual null
    expect(WebActors.match("foobar", "foobar")).toEqual []

  it "should exactly match booleans", ->
    for b in [true, false]
      expect(WebActors.match(b, not b)).toEqual null
      expect(WebActors.match(b, b)).toEqual []

  it "should not match dissimilar arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "a"])).toEqual null
    expect(WebActors.match(["a", "b"], ["a", "b", "c"])).toEqual null
    expect(WebActors.match(["a", "b"], ["a"])).toEqual null

  it "should match identical arrays", ->
    expect(WebActors.match(["a", "b"], ["a", "b"])).toEqual []

  it "should match subsets of object fields", ->
    expect(WebActors.match({a: 3}, {a: 3, b: 4})).toEqual []

  it "should not match objects with missing fields", ->
    expect(WebActors.match({a: 3, b: 4}, {a: 3})).toEqual null
