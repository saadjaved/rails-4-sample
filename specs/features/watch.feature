@javascript
Feature: Watch channel page
  Background:
    Given there are the following channels:
      | name |
      | test |
    And I am logged in
    And channel test has 10 videos

  Scenario: When I am on channel watch page and channel is not live, archive video is played.
    When I go to the 'watch channel test' page
    Then I see content 'ARCHIVE VIDEO'

  Scenario: When channel is live, video player has LIVE text.
    When channel test is live
    And I go to the 'watch channel test' page
    Then I see content 'LIVE'

  Scenario: When page is loaded, there are 8 videos available
    When I go to the 'watch channel test' page
    And I see 8 css '.watch-video-list-item-video'
    And I click link 'show more'
    And I see 10 css '.watch-video-list-item-video'
    And I click link 'show more'
    Then I do not see content 'show more'
    And I see 10 css '.watch-video-list-item-video'
