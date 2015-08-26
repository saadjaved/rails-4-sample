DeckPlayer = App.DeckPlayer
ChannelPage = App.ChannelPage
Participant = App.Participant
ChannelParticipantsSubscribtion = App.ChannelParticipantsSubscribtion

describe "ChannelPage", ->
  page = null
  window.$f = ->

  beforeEach ->
    page = new ChannelPage()

  afterEach ->
    ko.cleanNode(document.body)

  describe 'DeckPlayer', ->
    describe "#loadPlayer", ->
      it "Don't initializes player twice", ->
        playerSpy = spyOn($.fn, 'deckPlayer')
        element = document.createElement 'div'
        DeckPlayer.loadPlayer(element)
        DeckPlayer.loadPlayer(element)
        DeckPlayer.loadPlayer(element)
        expect(playerSpy.calls.count()).toEqual(1)

    describe "#loadPlayers", ->
      it "Loads players into all elements with [data-rtmp]", ->
        container = document.createElement "div"
        spyOn DeckPlayer, "loadPlayer"

        for n in [1..10]
          e = document.createElement("div")
          e.setAttribute "data-rtmp" , n
          container.appendChild(e)

        DeckPlayer.loadPlayers(container, true)
        expect(DeckPlayer.loadPlayer.calls.count()).toEqual(10)

  describe "#loadPlayers", ->
    it 'actually calls the DeckPlayer.loadPlayers', ->
      spyOn DeckPlayer, 'loadPlayers'
      page.loadPlayers()
      page.loadPlayers()
      page.loadPlayers()
      expect(DeckPlayer.loadPlayers.calls.count()).toEqual(3)

  describe 'ChannelParticipantsSubscribtion', ->
    location = Location.channelParticipantsPath()
    subscription = null
    successFn = null

    beforeEach ->
      jasmine.clock().install()
      spyOn($, 'getJSON').and.returnValue(success: (c) -> successFn = c)
      subscription = new ChannelParticipantsSubscribtion(page)

    afterEach ->
      jasmine.clock().uninstall()

    describe '#load', ->
      it 'makes GET request to channel_participants location', ->
        subscription.load()
        expect($.getJSON.calls.count()).toEqual(1)
        expect($.getJSON.calls.argsFor(0)).toEqual([location])

      describe '#success callback', ->
        it 'calls accepted callback', ->
          callback = jasmine.createSpy('spy')
          subscription.load(callback)
          data = {a: 1, b: 2, c: 3}
          successFn(data)
          expect(callback.calls.count()).toEqual(1)
          expect(callback.calls.argsFor(0)).toEqual [data]

        it 'replaces participants with received data on', ->
          spy = spyOn(subscription, 'replaceConnectedParticipants')
          subscription.load()
          data =
            connectedParticipants:
              a: 1
              b: 3
          successFn(data)
          expect(spy.calls.count()).toEqual(1)
          expect(spy.calls.argsFor(0)).toEqual([data.connectedParticipants])

    describe '#subscribe', ->
      it 'calls load', ->
        spyOn(subscription, 'load')
        subscription.subscribe()
        expect(subscription.load.calls.count()).toEqual(1)

      it 'accepts callback argument', ->
        spy = jasmine.createSpy('spy')
        subscription.subscribe(spy)
        successFn()
        expect(spy.calls.count()).toEqual(1)
        jasmine.clock().tick(subscription.waitTime)
        successFn([])
        expect(spy.calls.count()).toEqual(2)

      it 'enters a loop with timeout @waitTime, but each cycle starts on load().success callback', ->
        spyOn(subscription, 'subscribe').and.callThrough()
        spyOn(subscription, 'load').and.callThrough()
        subscription.subscribe()
        expect(subscription.load.calls.count()).toEqual(1)
        expect(subscription.subscribe.calls.count()).toEqual(1)

        successFn([])
        jasmine.clock().tick(subscription.waitTime)

        expect(subscription.load.calls.count()).toEqual(2)
        expect(subscription.subscribe.calls.count()).toEqual(2)

        jasmine.clock().tick(subscription.waitTime)

        expect(subscription.load.calls.count()).toEqual(2)
        expect(subscription.subscribe.calls.count()).toEqual(2)

        successFn([])
        jasmine.clock().tick(subscription.waitTime)

        expect(subscription.load.calls.count()).toEqual(3)
        expect(subscription.subscribe.calls.count()).toEqual(3)
