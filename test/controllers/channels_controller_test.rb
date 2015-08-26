require 'test_helper'

class ChannelsControllerTest < ActionController::TestCase
  setup do
    @user = create :user
    @channel = create :channel, user: @user
    sign_in @user
  end

  test 'GET #index' do
    get :index
    assert_response :success
    assert_not_nil assigns(:channels)
  end

  test 'GET #index displays public and users channels ordered by updated_at' do
    channel_2 = create :channel, updated_at: Time.current + 1.minutes
    create :channel_subscription, :operator, user: @user, channel: channel_2
    get :index
    assert_equal [channel_2, @channel], assigns(:channels).to_a
  end

  test "#active should show public channel only" do
    channel1 = create :channel
    channel2 = create :channel, :public
    WOWZA_CONFIG.stubs(:[]).with(:runtime).returns('')
    Wowza.stubs(:get_active_channels).returns ["Channel#{channel1.id}", "Channel#{channel2.id}"]

    get :active
    assert_equal [channel2], assigns(:channels).to_a
  end

  test "#new displayed successfully" do
    get :new
    assert_response :success
  end

  test "#new does not show is_public checkbox" do
    get :new
    assert_select "input#channel_is_public", false, 'No Public checkbox should be displayed'
  end

  test "#create creates channel successfully" do
    assert_difference('Channel.count', 1) do
    post :create, channel: { name: 'Super Channel' }
    end
    assert_redirected_to channel_show_path(assigns(:channel).token)
  end

  test "#create with blank ttl doesn't set ttl" do
    sign_in create(:user, :admin)
    post :create, channel: { name: 'Super Channel', ttl_in_hours: '' }
    @channel = assigns(:channel)
    assert @channel.ttl_in_hours.blank?
  end

  test "#create channel as non admin doesn't set ttl" do
    post :create, channel: { name: 'Super Channel' }
    @channel = assigns(:channel)
    assert @channel.ttl_in_hours.blank?
  end

  test "#creates a channel with private flag set by default"do
    post :create, channel: {name: 'Super Channel'}
    @channel = assigns(:channel)
    assert_equal true, !@channel.is_public
  end

  test "#creates a channel with curate_archive_video flag set false by default"do
    post :create, channel: {name: 'Super Channel'}
    @channel = assigns(:channel)
    assert_equal false, @channel.curate_archive_video
  end

  test '#create render new if channel invalid' do
    Channel.any_instance.stubs(:save).returns(false)
    post :create, channel: { name: 'Super Channel' }
    assert_response :success
    assert_template :new
  end

  test "#show admin can access" do
    sign_in create(:user, :admin)
    get :show, token: @channel.token
    assert_response :success
  end

  test "#show channel manager can access" do
    sign_in create(:user, :channel_manager)
    get :show, token: @channel.token
    assert_response :success
  end

  test "#show user can access" do
    @user = create(:user, :role => 'channel_creator')
    @channel = create(:channel, :user => @user)

    sign_in @user
    get :show, token: @channel.token
    assert_response :success
  end

  test "#show non-user is redirected to root path" do
    @other_user = create(:user)
    sign_in @other_user
    get :show, token: @channel.token
    assert_redirected_to root_path
  end

  test "#show non-logged in user is redirected to sign in path" do
    sign_out @user
    get :show, token: @channel.token
    assert_redirected_to root_path
  end

  test "#watch returns successfully" do
    stub_request(:get, @channel.hds_url)
    Channel.any_instance.stubs(:is_running?).returns(true)
    get :watch, token: @channel.token
    assert_response :success
    assert_equal @channel, assigns(:source)
  end

  # test "#watch 404 page is displayed in channel token is invalid" do
  #   get :watch, token: 'invalid_token'
  #   assert_response 404
  # end

  test "#watch user is redirected if a private video watch URL has unexpected format" do
    private_channel = create :channel, :private
    get :watch, token: private_channel.token , format: "com"
    assert_redirected_to root_path
  end

  test "#watch user is redirected if trying to watch other user private video" do
    @other_user = create :user, :guest
    sign_in @other_user
    private_channel = create :channel, :private
    stub_request(:get, private_channel.hds_url)
    get :watch, token: private_channel.token
    assert_redirected_to root_path
  end

  test 'GET #embed live channel' do
    stub_request(:get, @channel.hds_url)
    get :embed, token: @channel.token
    assert_response :success
    assert_match /#{@channel.hds_url}/, response.body
  end

  test 'GET #embed non-existent channel' do
    get :embed, token: 'wrong-token'
    assert_response :success
    assert_match 'Sorry, but this stream no longer available', response.body
  end

  test "should get edit" do
    get :edit, token: @channel.token
    assert_response :success
  end

  test "#edit does not show is_public checkbox" do
    get :edit, token: @channel.token
    assert_select "input#channel_is_public", false, 'No Public checkbox should be displayed'
  end

  test "#update successfully" do
    patch :update, token: @channel, channel: { name: @channel.name }
    assert_redirected_to channels_path
  end

  test "#update render edit if channel cannot be updated" do
    Channel.any_instance.stubs(:update).returns(false)
    put :update, token: @channel.token, channel: { name: @channel.name }
    assert_template :edit
  end

  test '#start_wowza is accessible by creator and redirects to channel path' do
    get :start_wowza, token: @channel.token
    assert_redirected_to channel_show_path(@channel.token)
  end

  test '#start_wowza is accessible by admin' do
    sign_in create(:user, :admin)
    get :start_wowza, token: @channel.token
    assert_redirected_to channel_show_path(@channel.token)
  end

  test '#start_wowza is accessible by channel manager' do
    sign_in create(:user, :channel_manager)
    get :start_wowza, token: @channel.token
    assert_redirected_to channel_show_path(@channel.token)
  end

  test '#start_wowza non-creator is redirected to root path' do
    @other_user = create(:user)
    sign_in @other_user
    get :start_wowza, token: @channel.token
    assert_redirected_to root_path
  end

  test '#start_wowza non-logged in user is redirected to sign in path' do
    sign_out @user
    get :start_wowza, token: @channel.token
    assert_redirected_to root_path
  end


  test '#stop_wowza is accessible by creator and redirect to channels path' do
    get :stop_wowza, token: @channel.token
    assert_redirected_to channels_path
  end

  test '#stop_wowza is accessible by admin' do
    sign_in create(:user, :admin)
    get :stop_wowza, token: @channel.token
    assert_redirected_to channels_path
  end

  test '#stop_wowza is accessible by channel manager' do
    sign_in create(:user, :channel_manager)
    get :stop_wowza, token: @channel.token
    assert_redirected_to channels_path
  end

  test '#stop_wowza non-creator is redirect to root path' do
    @other_user = create(:user)
    sign_in @other_user
    get :stop_wowza, token: @channel.token
    assert_redirected_to root_path
  end

  test '#stop_wowza non-logged in user is redirected to sign in path' do
    sign_out @user
    get :stop_wowza, token: @channel.token
    assert_redirected_to root_path
  end

  test '#stop_wowza set youtube_stream to false' do
    get :stop_wowza, token: @channel
    assert_equal @channel.youtube_stream, false
  end

  test '#is_live returns is_live state of channel' do
    @channel = create :channel, user: @user

    stub_request(:get, @channel.hds_url).to_return(status: 504)
    get :is_live, format: :json, token: @channel.token
    assert_equal response_as_json['is_live'], false

    Rails.cache.clear

    stub_request(:get, @channel.hds_url)
    get :is_live, format: :json, token: @channel.token
    assert_equal response_as_json['is_live'], true
  end

  test '#is_live is cached for 10 seconds' do
    @channel = create :channel, user: @user

    stub_request(:get, @channel.hds_url)
    get :is_live, format: :json, token: @channel.token
    assert_equal response_as_json['is_live'], true

    stub_request(:get, @channel.hds_url).to_return(status: 504)
    get :is_live, format: :json, token: @channel.token
    assert_equal response_as_json['is_live'], true

    Timecop.travel(Time.now + 10.seconds) do
      get :is_live, format: :json, token: @channel.token
      assert_equal response_as_json['is_live'], false
    end
  end

  test '#dump_delay should return 200 and message' do
    Wowza.expects(:post).with('dumpDelay', channelId: @channel.rtmp_name).returns([true, {message: "Channel output delay has been dumped."}, 200])
    post :dump_delay, token: @channel.token, format: :json
    assert_response 200
    assert_equal response.body, '{"message":"Channel output delay has been dumped."}'
  end

  test '#dump_delay should return 404 and message' do
    Wowza.expects(:post).with('dumpDelay', channelId: @channel.rtmp_name).returns([false, {message: "There was an error."}, 404])
    post :dump_delay, token: @channel.token, format: :json
    assert_response 404
    assert_equal response.body, '{"message":"There was an error."}'
  end

  test '#set_slate_video not calls Wowza directly' do
    Channel.any_instance.expects(:set_video)
    Wowza.expects(:set_slate_video).never
    get :set_slate_video, token: @channel.token, format: :json
  end

  # test '#set_slate_video should return 404 if channel not found' do
  #   get :set_slate_video, token: Time.now.to_i
  #   assert_response 404
  # end

  # test '#set_slate_video should return 404 if video not found' do
  #   get :set_slate_video, token: @channel.token, slate_video_id: Time.now.to_i
  #   assert_response 404
  # end

  test '#coordinates returns json with lat,lng from Channel#current_gps' do
    stream = create :stream, channels: [@channel], creator: @user
    gps_location = create :gps_location, streams: [stream]
    @channel.update output: stream
    get :coordinates, token: @channel.token, format: :json
    assert_equal response_as_json.to_json, { gps: { latitude: gps_location.latitude, longitude: gps_location.longitude } }.to_json
  end

  test '#watch renders watch' do
    stub_request(:get, @channel.hds_url)
    Channel.any_instance.stubs(:is_running?).returns(true)
    get :watch, token: @channel.token
    assert_template :watch
    assert_select 'div.columns.large-12.white-panel.watch-video'
  end

  test '#set_stream' do
    stream = create :stream, channels: [@channel]
    Wowza.expects(:post).with('setChannelOuputSourceLive', channelId: @channel.rtmp_name, streamId: stream.rtmp_name).returns([true, { message: 'Stream was successfully set' }, 200])
    get :set_stream, token: @channel.token, stream_token: stream.token, format: :json
    assert_response 200
    assert_equal({'message' => 'Stream was successfully set'}, response_as_json)
    assert_equal @channel.reload.output, stream
  end

  test '#set_stream returns error' do
    stream = create :stream, channels: [@channel]
    Wowza.expects(:post).with('setChannelOuputSourceLive', channelId: @channel.rtmp_name, streamId: stream.rtmp_name).returns([false, { message: 'There was an error' }, 404])
    get :set_stream, token: @channel.token, stream_token: stream.token, format: :json
    assert_response 404
    assert_equal({'message' => 'There was an error'}, response_as_json)
  end

  test '#set_stream when stream not found' do
    get :set_stream, token: @channel.token, stream_token: 'invalid_token', format: :json
    assert_response 404
    assert_equal({'message' => I18n.t('stream.not_exist')}, response_as_json)
  end

  test '#set_stream show custom error when video is not H.264 encoded (internal server error) occurs' do
    Wowza.fake!(false)
    stream = create :stream, channels: [@channel]
    channelId = ::Wowza.create_rtmp_name('channel', @channel.id)
    streamId = stream.rtmp_name
    stub_request(:post, "http://#{WOWZA_CONFIG[:deck]}:8080/api-deck/setChannelOuputSourceLive").
        with(body: {channelId: channelId, streamId: streamId}).
        to_return(status: 500, body: I18n.t('stream.errors.stream_less_data'), headers: {} )
    get :set_stream, token: @channel.token, stream_token: stream.token, format: :json
    @redis = stub('redis')
    @redis.stubs(:clear)
    Wowza.stubs(:original_redis).returns(@redis)
    assert_equal({'message' => I18n.t('stream.custom_errors.stream_less_data')}, response_as_json)
  end

  test '#flag_channel' do
    msg = "bad, bad, bad channel"
    post :flag_channel, token: @channel.token, flag_channel: { message: msg, page: 'abc' }, format: :json
    flag = ContentFlag.last
    assert_equal msg, flag.message
    assert_equal @channel, flag.content
    assert_equal @user, flag.author
    assert_equal ContentFlag::INAPPROPRIATE, flag.flag_type
    assert_equal 'abc', flag.page
  end

  test 'GET #watch_videos' do
    videos = 5.times.map do |index|
      create :archive_video, :channel_featured, :channel_source, source: @channel, created_at: Time.current - (index + 1).minute
    end
    stream = create :stream, channels: [@channel]
    video = create :archive_video, :channel_featured, :stream_source, source: stream, created_at: Time.current + 1.hour
    get :watch_videos, token: @channel.token, format: :json
    assert_response :success
    assert response_as_json.count, 3
  end

  test "start_youtube_live_on_create" do
    Channel.any_instance.stubs(:start_youtube_live_event)
    Channel.any_instance.stubs(:start_wowza).returns(true)

    User.any_instance.stubs(:has_provider?).returns(true)
    User.any_instance.stubs(:google).returns(SocialIdentity.new)
    User.any_instance.stubs(:refresh_google_oauth2_token!)
    YoutubeApi.any_instance.stubs(:prepare_live_event)
    Channel.any_instance.expects(:start_youtube_live_event)
    post :create, channel: { name: 'Super Channel', youtube_stream: 'true' }

  end

  test 'start_youtube_live_on_edit' do
    Channel.any_instance.stubs(:start_youtube_live_event)
    Channel.any_instance.stubs(:start_wowza).returns(true)

    User.any_instance.stubs(:has_provider?).returns(true)
    User.any_instance.stubs(:google).returns(SocialIdentity.new)
    User.any_instance.stubs(:refresh_google_oauth2_token!)
    YoutubeApi.any_instance.stubs(:prepare_live_event)
    Channel.any_instance.expects(:start_youtube_live_event)
    put :update, token: @channel.token, channel: { youtube_stream: 'true' }
  end

  test 'after starting youtube_event user is redirected to same channel edit page' do
    Channel.any_instance.stubs(:start_youtube_live_event)
    Channel.any_instance.stubs(:start_wowza).returns(true)

    User.any_instance.stubs(:has_provider?).returns(true)
    User.any_instance.stubs(:google).returns(SocialIdentity.new)
    User.any_instance.stubs(:refresh_google_oauth2_token!)
    YoutubeApi.any_instance.stubs(:prepare_live_event)
    Channel.any_instance.expects(:start_youtube_live_event)
    get :youtube_event, token: @channel
    assert_redirected_to edit_channel_path(@channel)
  end

  test '#youtube_event show custom error when live stream is not enabled error occurs' do
    identity = create :social_identity, :google_oauth2, user: @user
    mock_google_oauth2 create(:google_oauth2_auth, id: identity.uid)
    youtube_api = create(:youtube_api)
    stub_request(:get, 'https://www.googleapis.com/discovery/v1/apis/youtube/v3/rest').to_return(body: youtube_api.to_json, headers: { 'content-type' => 'application/json; charset=UTF-8'})
    stub_request(:post, 'https://www.googleapis.com/youtube/v3/liveBroadcasts?part=snippet,status').to_raise(Google::APIClient::ClientError.new(I18n.t('errors.messages.youtube_live_event.error')))
    get :youtube_event, token: @channel
    assert_equal flash[:error], I18n.t('errors.messages.youtube_live_event.custom_error')
    assert_redirected_to edit_channel_path(@channel)
  end

  test 'show custom error when live stream is not enabled error occurs on_edit' do
    identity = create :social_identity, :google_oauth2, user: @user
    mock_google_oauth2 create(:google_oauth2_auth, id: identity.uid)
    youtube_api = create(:youtube_api)
    stub_request(:get, 'https://www.googleapis.com/discovery/v1/apis/youtube/v3/rest').to_return(body: youtube_api.to_json, headers: { 'content-type' => 'application/json; charset=UTF-8'})
    stub_request(:post, 'https://www.googleapis.com/youtube/v3/liveBroadcasts?part=snippet,status').to_raise(Google::APIClient::ClientError.new(I18n.t('errors.messages.youtube_live_event.error')))
    put :update, token: @channel.token, channel: { youtube_stream: 'true' }
    assert_equal flash[:error], I18n.t('errors.messages.youtube_live_event.custom_error')
    assert_redirected_to edit_channel_path(@channel)
  end

  test 'show custom error when live stream is not enabled error occurs on_create' do
    identity = create :social_identity, :google_oauth2, user: @user
    mock_google_oauth2 create(:google_oauth2_auth, id: identity.uid)
    youtube_api = create(:youtube_api)
    stub_request(:get, 'https://www.googleapis.com/discovery/v1/apis/youtube/v3/rest').to_return(body: youtube_api.to_json, headers: { 'content-type' => 'application/json; charset=UTF-8'})
    stub_request(:post, 'https://www.googleapis.com/youtube/v3/liveBroadcasts?part=snippet,status').to_raise(Google::APIClient::ClientError.new(I18n.t('errors.messages.youtube_live_event.error')))
    post :create, channel: { name: 'Super Channel', youtube_stream: 'true' }
    assert_equal flash[:error], I18n.t('errors.messages.youtube_live_event.custom_error')
    assert_redirected_to edit_channel_path(Channel.last)
  end

  test "show_youtube_live_event_if_google_connected" do
    User.any_instance.stubs(:has_provider?).returns(true)
    User.any_instance.stubs(:google).returns(SocialIdentity.new)
    get :new
    assert_select "label.mute.st-channel_input-checkbox.youtube-stream"
  end

  test 'GET #active_streams' do
    stream = create :stream, channels: [@channel]
    get :active_streams, token: @channel.token, format: :json
    assert_equal response_as_json, { streams: [{ token: stream.token }] }.deep_stringify_keys
  end

  test 'GET #active_streams not authorized' do
    sign_in create(:user)
    get :active_streams, token: @channel.token, format: :json
    assert_response 403
  end

  test 'GET #streams' do
    stream = create :stream, channels: [@channel]
    Wowza.redis["stream:#{stream.rtmp_name}"] = {"hostLocal"=>"172.31.3.2", "streamId"=>stream.rtmp_name, "r"=>true, "cdn"=>true, "hostPublic"=>"54.215.244.254"}
    get :streams, token: @channel.token, format: :json, tokens: [stream.token]
    assert_equal response_as_json, {"streams"=>[{"token"=>stream.token, "rtmp_name"=>stream.rtmp_name, "rtmp_watch"=>response_as_json['streams'].first['rtmp_watch'], "chat_identity"=>stream.chat_room, "user"=>{"id"=>stream.creator.id, "name"=>stream.creator.name, "avatar_url"=>stream.creator.avatar.thumb.url}}]}
  end

  test 'GET #streams not authorized' do
    sign_in create(:user)
    get :streams, token: @channel.token, format: :json
    assert_response 403
  end

  test 'GET #streams_gps_locations' do
    stream = create :stream, channels: [@channel]
    gps_location = create :gps_location
    stream.gps_locations << gps_location
    Wowza.redis["stream:#{stream.rtmp_name}"] = {"hostLocal"=>"172.31.3.2", "streamId"=>stream.rtmp_name, "r"=>true, "cdn"=>true, "hostPublic"=>"54.215.244.254"}
    get :streams_gps_locations, token: @channel.token, format: :json, tokens: [stream.token]
    assert_equal response_as_json, {"streams"=>[{"token"=>stream.token, "rtmp_name"=>stream.rtmp_name, "chat_identity"=>stream.chat_room, "user"=>{"id"=>stream.creator.id, "name"=>stream.creator.name, "avatar_url"=>stream.creator.avatar.thumb.url}, "gps_locations"=>[{"latitude"=>gps_location.latitude.as_json, "longitude"=>gps_location.longitude.as_json}]}]}
  end

  test 'GET #streams_gps_locations not authorized' do
    sign_in create(:user)
    get :streams_gps_locations, token: @channel.token, format: :json
    assert_response 403
  end

  test "#create If channel name is blank, channel doesn't create but uploaded image should remain on the page" do
    test_photo = ActionDispatch::Http::UploadedFile.new({ :filename => 'test.png', :type => 'image/jpeg', :tempfile => File.new("#{Rails.root}/test/photos/test.png") })
    post :create, channel: { image: test_photo}
    assert_match /\/uploads\/tmp\/\w\S{5,20}\/test.png/, response.body
  end

  test 'POST #add_streams' do
    user = create :user
    stream_1 = create :stream, creator: user
    stream_2 = create :stream, creator: user
    stream_3 = create :stream, creator: user, channels: [@channel]
    xhr :post, :add_streams, { format: :json, token: @channel.token, user: { email: user.email } }
    assert_response 200
    assert_equal response_as_json, { 'message' => I18n.t('channels.add_streams', count: 2) }
    assert_equal @channel.streams.sort, [stream_1, stream_2, stream_3].sort
  end

  test 'POST #add_streams error' do
    xhr :post, :add_streams, { format: :json, token: @channel.token, user: { email: 'email_does_not_exist' } }
    assert_response 400
    assert_equal response_as_json, { 'message' => I18n.t('channels.add_streams_error') }
  end
end
