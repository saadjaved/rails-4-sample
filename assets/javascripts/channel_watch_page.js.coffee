###jslint vars: true, nomen: true, browser: true ###

###global _: false, $: false, moment: false ###

((App, document, ko) ->

  scrollToTop = ->
    $(document).scrollTop 0
    return

  Player = (opts) ->
    @opts = opts or {}
    @el = $('#player')
    @protocol = ko.observable('stringwire')
    @playingVideo = ko.observable(false)
    @videoUrl = ko.observable()
    return

  Video = (data) ->
    $.extend this, data
    @created_at = moment.serverToLocalTime(parseInt(data.created_at, 10), 'X').format('DD MMM YYYY - HH:mm')
    @updated_at = moment.serverToLocalTime(parseInt(data.updated_at, 10), 'X').format('DD MMM YYYY - HH:mm')
    @isPlaying = ko.observable(false)
    @duration = data.duration or '--:--:--'
    @creator = data.creator
    return

  FlagContent = (page) ->
    flagged = ko.observableArray([])
    self = this
    currentVideo = ko.computed(->
      App.find page.videos(), (v) ->
        v.url and v.url == page.player.videoUrl()
    )

    closePopup = ->
      $('#flag-popup').foundation 'reveal', 'close'
      return

    @message = ko.observable()

    @send = ->
      if !self.isEnabled()
        return
      if !page.player.playingVideo()
        App.flagChannel page.channelToken, self.message(), location.pathname, success: ->
          flagged.push 'channel'
          self.message ''
          closePopup()
          return
      else
        App.flagVideo currentVideo().id, self.message(), location.pathname, success: ->
          flagged.push page.player.videoUrl()
          self.message ''
          closePopup()
          return
      return

    @closePopup = closePopup
    @isEnabled = ko.computed(->
      if !page.player.playingVideo() and flagged().indexOf('channel') == -1
        return true
      page.player.videoUrl() and flagged.indexOf(page.player.videoUrl()) == -1
    )
    return

  ChannelWatchPage = (opts) ->
    page = this
    @opts = opts or {}
    @popup = new (App.Popup)
    @player = new Player(jsCfg)
    @channelId = jsCfg.channelId
    @isResponsive = $('body').width() < 640
    @channelToken = jsCfg.channelToken
    @videosPage = 1
    # this.endOfVideos = ko.observable(false);
    @videos = ko.observableArray([])
    @videoUrl = ko.observable()
    @channelStatus = ko.observable(true)
    # this.loadVideos();
    @player.playChannel()
    @source = jsCfg.source
    @lastCoordinates = ko.observable()
    @lastLocation = ko.observable()
    @flag = new FlagContent(this)
    @chat = new (App.ChannelWatchChat)
    @map = new (App.DeckMap)
    @shortUrl = jsCfg.shortUrl
    @archive_player = new (ChannelWatchPage.Player)(@isResponsive)
    @archive_videos = new (ChannelWatchPage.Videos)('archive', @channelToken, @opts.source)
    @archive_videos.get_items()

    @openInNewWindow = ->
      video = page.archive_player.video()
      if video and video.url
        window.open video.watch_url, '_blank'
        player = $(@archive_player.player.$el.find('object'))[0]
        player.pause()
      return

    @downloadVideo = ->
      App.routes.videos.download { videoToken: page.archive_player.video().data.token }, success: ->
      location.href = page.archive_player.video().data.url
      return

    @liveShareToFacebook = ->
      App.facebook.share @shortUrl
      return

    @liveShareToTwitter = ->
      App.twitter.share @shortUrl
      return

    @liveShareToGplus = ->
      App.gplus.share @shortUrl
      return

    @archiveShareToFacebook = ->
      video = page.archive_player.video()
      if video and video.url
        App.facebook.share video.watch_url
      return

    @archiveShareToTwitter = ->
      video = page.archive_player.video()
      if video and video.url
        App.twitter.share video.social_text
      return

    @archiveShareToGplus = ->
      video = page.archive_player.video()
      if video and video.url
        App.gplus.share video.watch_url
      return

    App.facebook.init()
    @isChannelRunning = new (App.IsChannelRunning)(this)
    @isChannelRunning.update()
    @isChannelRunning.start()
    @playArchiveVideo = ko.computed((->
      if !@channelStatus() and !@player.playingVideo()
        if @archive_videos.items().length > 0
          @player.playVideo @archive_videos.items()[0].url
        return true
      else if @channelStatus()
        @player.playChannel()
        return false
      false
    ), this)
    $ ->
      App.zeroClipboard()
      return
    ko.applyBindings this, document.documentElement
    return

  'use strict'
  page = undefined
  $.extend Player.prototype,
    setOptions: (opts) ->
      self = this
      @el.JDPlayer()
      App.ignoreErrors ->
        self.el.JDPlayer 'destroy'
        return
      @el.JDPlayer 'setOptions', opts
      @el.JDPlayer 'embed'
      return
    playChannel: ->
      @videoUrl null
      @setOptions
        protocol: @protocol()
        hls: @opts.hls
        hds: @opts.hds
        akamaiHds: @opts.akamaiHds
        akamaiHls: @opts.akamaiHls
        akamai: true
        streamType: 'live'
      @playingVideo false
      return
    playVideo: (url) ->
      @videoUrl url
      @setOptions
        akamai: false
        hds: url
        hls: url
        streamType: 'vod'
        loop: 'false'
      @playingVideo true
      scrollToTop()
      return
  $.extend Video.prototype, play: ->
    page.player.playVideo @url
    return

  App.IsChannelRunning = (page) ->
    self = page
    ob = ko.observable()
    timeout = 10000
    $.extend ob,
      source: self.source
      channelToken: self.channelToken
      getChannelStatus: (callback) ->
        $.getJSON(window.Location.isChannelRunningPath(ob.source, ob.channelToken)).success (data) ->
          self.channelStatus data.is_live
          callback data.is_live
          return
        return
      update: (callback) ->
        ob.getChannelStatus (status) ->
          ob status
          if callback
            callback status
          return
        return
      start: ->
        ob.timeoutId = setTimeout((->
          ob.update ->
            ob.start()
            return
          return
        ), timeout)
        return
      stop: ->
        clearTimeout ob.timeoutId
        return
    ob

  ChannelWatchPage.Videos = (type, channelToken, source) ->
    self = this
    self.items = ko.observableArray([])
    self.page = 1
    self.per_page = 8
    self.filtered_by4 = ko.computed(->
      App.byNumber self.items(), 4
    )
    self.lock = false

    self.get_items = (filters) ->
      # Prevent multiple AJAX requests before complete
      if self.lock
        return
      self.lock = true
      $('.no-items').toggleClass 'hide', true
      $('.load-items a').toggleClass 'hide', true
      $('.load-items img').toggleClass 'hide', false
      App.routes.channels.videos {
        source: source
        channelToken: channelToken
        page: self.page
      },
        success: (data) ->
          if data.length
            App.each data, (item) ->
              self.items.push new (ChannelWatchPage.Video)(item)
              return
            $('.load-items a').toggleClass 'hide', data.length < self.per_page
          else
            $('.no-items').toggleClass 'hide', self.items().length > 0
            $('.load-items a').toggleClass 'hide', true
          return
        complete: ->
          $('.load-items img').toggleClass 'hide', true
          self.lock = false
          return
      self.page += 1
      return

    self

  ChannelWatchPage.Channel = (data) ->
    data = data or {}
    @data = data
    @id = data.id
    @name = data.name
    return

  ChannelWatchPage.Map = ->
    self = this
    defaultCenter = 
      lat: 12.389063576792118
      lng: 3.8816666666666766
    self.map = new (App.Gmaps)('#map')
    self.resize = self.map.triggerResize

    self.setCoordinates = (lat, lng) ->
      self.resize()
      if lat and lng
        self.map.setMarker lat, lng, 'videos-marker'
        self.map.setCenter lat, lng
        self.map.setZoom 16
      else
        self.map.unsetMarker 'videos-marker'
        self.map.setZoom 1
        self.map.setCenter defaultCenter.lat, defaultCenter.lng
      return

    return

  $.extend ChannelWatchPage.prototype,
    loadVideos: ->
      if @endOfVideos() == true
        return
      self = this
      App.routes.channels.videos {
        source: jsCfg.source
        channelToken: @channelToken
        page: self.videosPage
      }, success: (videos) ->
        if videos.length < 0
          self.endOfVideos true
          return
        _.each videos, (video) ->
          self.videos.push new Video(videos)
          return
        self.videos.sort (left, right) ->
          lid = left.id
          rid = right.id
          if lid < rid
            return 1
          if lid > rid
            return -1
          0
        self.videosPage = self.videosPage + 1
        return
      return
    onJavaScriptBridgeCreated: (playerId, event) ->
      if event == 'play'
        @highLightPlayingVideo()
      if event == 'emptied'
        setTimeout (->
          page.startNextVideo()
          return
        ), 50
      return
    unHighListPlayingVideo: ->
      _.each @videos(), (v) ->
        v.isPlaying false
        return
      return
    highLightPlayingVideo: ->
      @unHighListPlayingVideo()
      index = _.indexOf(@videos(), _.findWhere(@videos(), url: @player.videoUrl()))
      @videos()[index].isPlaying true
      return
    startNextVideo: ->
      index = _.indexOf(@videos(), _.findWhere(@videos(), url: @player.videoUrl()))
      size = _.size(@videos())
      if index >= size - 1 and @source == 'channels'
        @player.playVideo @videos()[0].url
      else
        @player.playVideo @videos()[index + 1].url
      return
    playChannel: ->
      @unHighListPlayingVideo()
      @player.playChannel()
      return
  App.ChannelWatchPage = ChannelWatchPage
  return
) window.App, document, window.ko

# ---
# generated by js2coffee 2.0.4