@javascript
Feature: Channel edit page
  Background:
    Given I am logged in
    And there are the following channels:
      | name |
      | test |

  Scenario: User can create YouTube live event
    And I have google_oauth2 account connected
    When I go to the 'channel test edit' page
    And I see content 'Channel should be restarted before creating a YouTube LIVE event'
    And I click css '.youtube-stream'
    And I click button 'Save changes'
    And I see content 'Channel was successfully updated.'
    And I go to the 'channel test edit' page
    And I click link 'Create YouTube LIVE Event'
    Then I see content 'YouTube live event was successfully created.'

  # Scenario: User can create YouTube live event after account connect
  #   When I go to the 'channel test edit' page
  #   And I do not see content 'Channel should be restarted before creating a YouTube LIVE event'
  #   And I click link 'Connect Google+ Account'
  #   And I see content 'Successfully authenticated from Google_oauth2 account.'
  #   And I click css '.youtube-stream'
  #   And I click button 'Save changes'
  #   And I see content 'Channel was successfully updated.'
  #   And I go to the 'channel test edit' page
  #   And I click link 'Create YouTube LIVE Event'
  #   Then I see content 'YouTube live event was successfully created.'

  Scenario: User can't create YouTube live event for non-created channel
    And I am logged in as different admin user
    When I go to the 'channel test edit' page
    Then I do not see content 'Channel should be restarted before creating a YouTube LIVE event'
    And I do not see link 'Connect Google+ Account'
    And I do not see link 'Create YouTube LIVE Event'

  Scenario:  User sees default image on channel edit page when image is uploading
    When channel test image_tmp is populated
    And I go to the 'channel test edit' page
    And I see content 'Image is being processed'
    And I click css '.st-input-upload-area_close-btn'
    Then I see content 'Drag an image here'

  Scenario: User sees uploaded image on channel edit page
    When channel test image is uploaded
    And I go to the 'channel test edit' page
    Then I see channel 'test' uploaded image

  Scenario: User can crop image
    When I go to the 'channel test edit' page
    And I attach image 'channel_image'
    And I see css '#channel_image_cropbox'
    And I click css '.st-input-upload-area_close-btn'
    And I do not see css '#channel_image_cropbox'
    And I attach image 'channel_image'
    And I see css '#channel_image_cropbox'
    And I hover over '.cropFrame'
    Then I see css '.cropFrame.hover'
