/*global jasmine: false, describe: false, beforeEach: false, afterEach: false, it: false, spyOn: false, expect: false */
/*jslint vars: true */
'use strict';
/*global App, testResponses*/

describe('App.ChannelWatchPage', function () {
  beforeEach(function () {
    jasmine.Ajax.install();
  });

  afterEach(function () {
    jasmine.Ajax.uninstall();
    window.ko.cleanNode(document.body);
  });

  it('gets last coordinates from /channels/<id>/current_coordinates.json', function () {
    var coords;
    App.ChannelWatchPage.prototype.getLastCoordinates.call({channelId: 111}, function (data) {
      coords = data;
    });

    var request = jasmine.Ajax.requests.mostRecent();
    request.response(testResponses.lastCoordinates);

    expect(request.url).toEqual(window.Location.channelLastCoordinatesPath(111));
    expect(coords.lat).toEqual(20);
    expect(coords.lng).toEqual(40);
  });

  it('updates lastCoordinates variable', function () {
    var page = new App.ChannelWatchPage();
    page.updateCoordinates();

    jasmine.Ajax.requests.mostRecent().response(testResponses.lastCoordinates);
    expect(page.lastCoordinates()).toEqual({lat: 20, lng: 40});
  });
});
