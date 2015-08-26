require 'rails_helper'

RSpec.describe Channel, type: :model do
  let(:model) { described_class }

  describe 'CRUD operations' do
    subject(:item) { create model }

    it_behaves_like 'model create'
    it_behaves_like 'model update', :description, Faker::Lorem.sentence
    it_behaves_like 'model destroy'
  end

  describe 'Validation' do
    it_behaves_like 'model validation', :name, :user
    it_behaves_like 'image validation', :image
    it_behaves_like 'sanitize fields', :name, :description
    it_behaves_like 'slug generation'
    it_behaves_like 'token generation', 4

    it 'has one creator' do
      item = create model
      item.channel_subscriptions << create(:channel_subscription, :creator)
      expect(item).to_not be_valid
      expect(item.errors[:creator].any?).to be_truthy
      expect{ item.creator_subscription = nil }.to raise_exception(ActiveRecord::RecordNotSaved)
    end
  end

  describe 'Associations' do
    it_behaves_like 'polymorphic association', :output, Stream
    it_behaves_like 'polymorphic association', :output, SlateVideo
    it_behaves_like 'has_many association', ChannelSubscription, true
    it_behaves_like 'has_many association', ChannelSubscription, true do
      let (:item_associated) { create :channel_subscription, :operator }
      let (:model_association) { :operator_subscriptions }
    end
    it_behaves_like 'has_many association', ContentFlag, false do
      let (:item_associated) { create :content_flag, :channel_content }
    end
    it_behaves_like 'has_many association', ChannelInvite, false do
      let (:model_association) { :invites }
    end
    it_behaves_like 'has_one association', User, false do
      let (:model_association) { :creator }
    end
    it_behaves_like 'has_many association', ArchiveVideo, false do
      let (:model_association) { :source_archive_videos }
    end
    it_behaves_like 'habtm association', ArchiveVideo
    it_behaves_like 'habtm association', Stream
  end

  describe 'Callbacks' do
    subject(:item) { create model }

    it '#set_short_url sets short url' do
      expect(item.short_url).to eq 'http://stw.re/test'
    end
  end

  describe 'Scopes' do
    it '.unrestricted' do
      item_1 = create model, :public
      item_2 = create model
      expect(model.unrestricted).to eq [item_1]
    end

    it '.restricted' do
      item_1 = create model
      item_2 = create model, :public
      expect(model.restricted).to eq [item_1]
    end
  end

  describe 'Methods' do
    subject(:item) { create model }

    describe '#short_url' do
      before { item.update_column :short_url, nil }

      it 'returns short_url' do
        expect(item.short_url).to eq Rails.application.routes.url_helpers.channel_watch_url(item.token, host: Rails.application.config.action_mailer.default_url_options[:host])
      end
    end

    describe '#thumbnail' do
      it 'returns thumbnail' do
        archive_video = create :archive_video, :channel_source, source: item
        expect(item.thumbnail).to eq archive_video.thumbnail
      end

      it 'returns nil' do
        expect(item.thumbnail).to be_nil
      end
    end

    describe '#ping' do
      it 'changes last_active_at' do
        Timecop.travel(Time.now + 1.hour) do
          expect{ item.ping }.to change{ item.last_active_at }
        end
      end
    end

    describe '#current_gps' do
      it 'returns gps_loction' do
        gps_location = create :gps_location
        item.update! output: create(:stream, gps_locations: [gps_location])
        expect(item.current_gps).to eq(gps_location)
      end

      it 'returns nil' do
        expect(item.current_gps).to be_nil
      end
    end

    describe '#subscribe_user!' do
      let(:user) { create :user }

      it 'adds new subscriber' do
        item.subscribe_user!(user, %i( participant ))
        expect(item.subscribers).to include(user)
        expect(item.channel_subscriptions.count).to eq(2)
      end

      it 'replaces existing subscriber' do
        item.subscribe_user!(user, %i( follower ))
        expect(item.channel_subscriptions.count).to eq(2)
        item.subscribe_user!(user, %i( participant ))
        expect(item.channel_subscriptions.count).to eq(2)
      end
    end

    describe '#unsubscribe_user!' do
      let(:user) { create :user }
      let(:channel_subscription) { create :channel_subscription, channel: item, user: user }

      it 'removes subscriber' do
        channel_subscription.valid?
        item.unsubscribe_user! user, %w{ participant }
        expect(channel_subscription.reload.is?(:participant)).to be_falsey
      end

      it 'raises error' do
        expect{ item.unsubscribe_user!(user, %i( participant )) }.to raise_error
      end
    end

    describe '#user_subscribed?' do
      let(:user) { create :user }
      let(:channel_subscription) { create :channel_subscription, channel: item, user: user }

      it 'returns true' do
        channel_subscription.valid?
        expect(item.user_subscribed?(user)).to be_truthy
      end

      it 'returns false' do
        expect(item.user_subscribed?(user)).to be_falsey
      end
    end

    describe '#subscription_available?' do
      let(:user) { create :user }

      it 'returns true' do
        channel_subscription = create :channel_subscription, channel: item, user: user
        expect(item.subscription_available?(user)).to be_truthy
      end

      it 'returns false' do
        channel_subscription = create :channel_subscription, channel: item, user: user, roles: []
        expect(item.subscription_available?(user)).to be_falsey
      end
    end

    # @TODO unit tests for YoutubeApi
    describe '#start_youtube_live_event' do
      let(:social_identity) { create :social_identity, :google_oauth2, user: item.creator }
      before do
        Timecop.freeze do
          mock_google_oauth2
          mock_youtube
        end
      end

      it 'updates social_identity oatuh_token' do
        social_identity.update! oauth_expires_at: Time.current - 1.hour
        expect{ item.start_youtube_live_event }.to change { social_identity.reload.oauth_token }
        expect(social_identity.expired?).to be_falsey
      end

      it 'runs YoutubeApi#prepare_live_event' do
        social_identity.valid?
        expect(item.start_youtube_live_event).to be_truthy
      end
    end

    describe '#has_youtube_cdn?' do
      it 'returns true' do
        item.update! youtube_rtmp_endpoint: 'youtube_rtmp_endpoint', youtube_rtmp_name: 'youtube_rtmp_name'
        expect(item.has_youtube_cdn?).to be_truthy
      end

      it 'returns false' do
        expect(item.has_youtube_cdn?).to be_falsey
      end
    end

    describe '#chat_room' do
      it 'returns chat_room' do
        expect(item.chat_room).to eq "channel-#{item.token}"
      end
    end

    describe '#hds_url, #hls_url' do
      it 'returns hds_url' do
        expect(item.hds_url).to eq("#{ENV['WOWZA_LIVESTREAM_URL']}/channel/#{item.rtmp_name}/manifest.f4m")
      end

      it 'returns hls_url' do
        expect(item.hls_url).to eq("#{ENV['WOWZA_LIVESTREAM_URL']}/channel/#{item.rtmp_name}/playlist.m3u8")
      end
    end

    describe '#is_live?' do
      before { Rails.cache.clear }

      it 'returns true' do
        stub_request(:get, item.hds_url)
        expect(item.is_live?).to be_truthy
      end

      it 'returns false' do
        stub_request(:get, item.hds_url).to_return(status: 504)
        expect(item.is_live?).to be_falsey
      end
    end

    describe '#as_api_json' do
      it 'returns as_api_json' do
        expect(item.as_api_json).to eq({ id: item.id, token: item.token, code: item.code, name: item.name, description: item.description, short_url: item.short_url, curate_archive_video: item.curate_archive_video, created_at: item.created_at, updated_at: item.updated_at}.stringify_keys!)
      end
    end
  end

  describe 'Wowza' do
    subject(:item) { create model }
    let(:item_wowza) { create :wowza_channel, channelId: item.rtmp_name }

    describe '#host_local' do
      it 'returns IP address' do
        expect(Wowza).to receive(:channel_info).with(item.rtmp_name).and_return(item_wowza)
        expect(item.host_local).to eq item_wowza['hostLocal']
      end

      it 'returns empty string' do
        expect(item.host_local).to eq ''
      end
    end

    describe '#rtmp' do
      it 'returns rtmp url' do
        expect(Wowza).to receive(:channel_info).with(item.rtmp_name).and_return(item_wowza).twice
        expect(Wowza).to receive(:generate_rtmp_play_token).with(item.rtmp_name).and_return('token')
        expect(item.rtmp).to eq "rtmp://#{item_wowza['hostPublic']}/deck/#{item.rtmp_name}?token=token"
      end

      it 'returns false' do
        expect(item.rtmp).to eq false
      end
    end

    describe '#rtmp_name' do
      it 'returns rtmp_name' do
        expect(item.rtmp_name).to eq(Wowza.create_rtmp_name('channel', item.id))
      end
    end

    describe '#is_running?' do
      it 'returns true' do
        expect(Wowza).to receive(:channel_info).with(item.rtmp_name).and_return(item_wowza)
        expect(item.is_running?).to be_truthy
      end

      it 'returns false' do
        expect(item.is_running?).to be_falsey
      end
    end

    describe '#start_wowza' do
      let (:request_params) { {
        channelId: item.rtmp_name,
        channelMode: 0,
        publish: item.publish_to_cdn?,
        record: item.is_recorded?,
        liveStreams: []
      } }

      it 'returns nil if channel is running' do
        expect(Wowza).to receive(:channel_info).with(item.rtmp_name).and_return(item_wowza)
        expect(item.start_wowza).to be_nil
      end

      it 'updates last_active_at' do
        expect{ item.start_wowza }.to change { item.last_active_at }
      end

      it 'runs Wowza#start_channel' do
        expect(item.start_wowza).to eq [['startChannel', request_params]]
      end

      it 'runs Wowza#start_channel with youtube params' do
        item.update! youtube_rtmp_endpoint: 'youtube_rtmp_endpoint', youtube_rtmp_name: 'youtube_rtmp_name'
        request_params.merge!(youTube: { host: item.youtube_rtmp_endpoint, streamName: item.youtube_rtmp_name })
        expect(item.start_wowza).to eq [['startChannel', request_params]]
      end

      it 'runs Wowza#start_channel with ttl param' do
        Timecop.freeze do
          item.update! ttl_in_hours: 1000
          request_params.merge!(ttl: (Time.current + item.ttl_in_hours.hours).to_i * 1000)
          expect(item.start_wowza).to eq [['startChannel', request_params]]
        end
      end
    end

    describe '#stop_wowza' do
      let(:stream) { create :stream }
      before { item.update! output: stream }

      context 'when is running' do
        it 'updates output to nil' do
          expect{ item.stop_wowza }.to change{ item.output }.from(stream).to(nil)
        end

        it 'returns nil' do
          expect( item.stop_wowza ).to be_nil
        end
      end

      context 'when is not running' do
        before { expect(Wowza).to receive(:channel_info).with(item.rtmp_name).and_return(item_wowza) }

        it 'updates output to nil' do
          expect{ item.stop_wowza }.to change{ item.output }.from(stream).to(nil)
        end

        it 'returns nil' do
          expect(item.stop_wowza).to eq [['stopChannel', { channelId: item.rtmp_name }]]
        end
      end
    end

    describe '#set_stream' do
      let(:stream) { create :stream, channels: [item] }

      context 'when stream is not live' do
        it 'returns false if stream does not belong to channel' do
          stream.update! channels: []
          expect(item.set_stream(stream.token)).to eq [false, { message: I18n.t('stream.not_exist') }, 404]
        end

        it 'returns false if stream is not live' do
          stream.update! status: :ended
          expect(item.set_stream(stream.token)).to eq [false, { message: I18n.t('stream.not_exist') }, 404]
        end
      end

      context 'when stream is live' do
        it 'runs Wowza#set_stream' do
          expect(item.set_stream(stream.token)).to eq [['setChannelOuputSourceLive', { channelId: item.rtmp_name, streamId: stream.rtmp_name}], nil, nil]
        end

        it 'updates channel output' do
          expect{ item.set_stream(stream.token) }.to change{ item.output }.from(nil).to(stream)
        end
      end
    end

    describe '#set_video' do
      let(:slate_video) { create :slate_video }

      it 'runs Wowza#set_slate_video' do
        expect(Wowza).to receive(:set_slate_video).with(item.rtmp_name, slate_video.path)
        expect{ item.set_video(slate_video.id) }.to change { item.output }.from(nil).to(slate_video)
      end
    end
  end
end
