class ChannelsController < ApplicationController
  include Watchable
  before_action :set_channel, only: %i( active_streams add_streams clear_source dump_delay )

  def index
    @channels = current_user.operated_channels.includes(:archive_videos).order(updated_at: :desc).page(params[:page])
  end

  def active
    @channels = Channel.active_channels.unrestricted
  end

  def show
    authorize! :start, @channel
    @operators = @channel.operator_subscriptions.includes(:user).to_a.delete_if { |o| o.is?(:creator) }.map(&:as_json_deck)
  end

  def new
    authorize! :create, Channel
    @channel = Channel.new user: current_user
  end

  def create
    authorize! :create, Channel
    @channel = Channel.new channel_params.merge(user: current_user)
    if @channel.save
      if current_user.has_provider?('google_oauth2') && current_user.id == @channel.creator.id && @channel.youtube_stream?
        data, status = @channel.start_youtube_live_event
      end
      return redirect_after_create(data, status)
    else
      render action: 'new'
    end
  end

  def edit
    authorize! :update, @channel
  end

  def update
    authorize! :update, @channel
    if @channel.update(channel_params)
      if current_user.has_provider?('google_oauth2') && current_user.id == @channel.creator.id && @channel.youtube_stream? && @channel.youtube_stream_id.blank?
        data, status = @channel.start_youtube_live_event
      end
      return redirect_after_update(data, status)
    else
      render action: 'edit'
    end
  end

  def set_stream
    authorize! :update, @channel

    success, data, status = @channel.set_stream(params[:stream_token])
    render status: status, json: data
  end

  def youtube_event
    authorize! :update, @channel

    data, status = @channel.start_youtube_live_event
    message = if status.to_i >= 400
      { error: data }
    else
      { success: t('channel.youtube_event_success') }
    end

    redirect_to edit_channel_path(@channel), flash: message
  end

  def add_streams
    authorize! :update, @channel
    begin
      user = User.find_by! email: params.fetch(:user).fetch(:email)
      streams = user.streams.live - @channel.streams
      streams.each do |stream|
        @channel.streams << stream
        Resque.enqueue AcquireLiveStream, Array(@channel.id), stream.id
      end
      render json: { message: t('channels.add_streams', count: streams.length) }
    rescue => ex
      Bugsnag.notify(ex)
      render json: { message: t('channels.add_streams_error') }, status: 400
    end
  end
  
  def streams
    authorize! :update, @channel
    @streams = @channel.streams.live.where(token: params[:tokens]).includes(:creator).to_a
    @streams.keep_if{ |s| s.rtmp_watch.present? }
  end

  def streams_gps_locations
    authorize! :update, @channel
    respond_to do |format|
      format.json do
        @streams = @channel.streams.live.where(token: params[:tokens])
      end
    end
  end

  # API call to start deck instance on Wowza
  def start_wowza
    authorize! :start, @channel
    @channel.start_wowza
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to channel_show_path(@channel) }
    end
  end

  # API call to stop deck instance on Wowza
  def stop_wowza
    authorize! :stop, @channel
    @channel.stop_wowza
    set_youtube_stream_status(false)
    respond_to do |format|
      format.json { head :no_content }
      format.html { redirect_to channels_path }
    end
  end

  def flag_channel
    respond_to do |format|
      format.json do
        render json: {}, status: flag_content(@channel, flag_channel_params[:message], flag_channel_params[:page]) ? 200 : 400
      end
    end
  end

  def watch_videos
    @videos = ArchiveVideo.by_channel(@source).featured.accessible_by(current_ability, :read).includes(:user).order(created_at: :desc).page(params[:page]).per 8
  end

  private
    def flag_channel_params
      params.require(:flag_channel).permit(:message, :page)
    end

    def slate_videos
      SlateVideo.all
    end
    helper_method :slate_videos

    def set_channel
      @channel = Channel.find_by! token: params[:token]
    end

    def channel_params
      permitted_params = [:name, :description, :email_alert, :image, :image_cache, :curate_archive_video, :youtube_stream, :youtube_rtmp_endpoint, :youtube_rtmp_name, :image_crop_x, :image_crop_y, :image_crop_w, :image_crop_h]
      permitted_params += [:is_recorded, :publish_to_cdn, :ttl_in_hours] if admin_signed_in?
      params.require(:channel).permit(permitted_params)
    end

    def set_youtube_stream_status(status = false)
      @channel.youtube_stream = status
      @channel.save!
    end

    def redirect_after_create(message, status)
      if status.to_i >= 400
        redirect_to edit_channel_path(@channel), :flash => { :error => message }
      else
        @channel.start_wowza
        redirect_to channel_show_path(@channel), notice: t("controller.channel_created")
      end
    end

  def redirect_after_update(message, status)
    if status.to_i >= 400
      redirect_to edit_channel_path(@channel), :flash => { :error => message }
    else
      redirect_to channels_path, notice: t("controller.channel_updated")
    end
  end

end
