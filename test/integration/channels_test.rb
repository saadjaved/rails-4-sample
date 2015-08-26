require 'test_helper'

class ChannelsTest < ActionDispatch::IntegrationTest
  setup do
    @user = create :user
    @channel = create :channel, user: @user
    @slate_videos = create_list :slate_video, 5
    login_as @user
  end

  test 'Back to My Channels button at edit page should redirect to My Channels page' do
    get "/channels/#{@channel.token}/edit"
    assert response.body.match(channels_path)
    assert_response :success
  end

  test "Start Channel successfully" do
    get "/channel/#{@channel.token}"
    assert_response :success
  end
end
