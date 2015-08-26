require 'channel/wowza'

class Channel < ActiveRecord::Base
  include ::Channel::Wowza
  include Tokenable
  include Sluggable
  include Sanitizable

  # Settings
  mount_uploader :image, FogChannelImageUploader
  store_in_background :image
  tokenable_by 3
  sanitizable_by :name, :description
  paginates_per 12
  self.slug_column = 'slug'
  self.slug_from = proc { name }

  # Associations
  belongs_to :output, polymorphic: true
  has_many :channel_subscriptions, dependent: :destroy
  has_one :creator_subscription, -> { ChannelSubscription.creator }, class_name: ChannelSubscription
  has_many :operator_subscriptions, -> { ChannelSubscription.operator }, class_name: ChannelSubscription
  has_many :content_flags, as: :content, dependent: :destroy
  has_many :invites, class_name: 'ChannelInvite', dependent: :destroy
  has_one :creator, through: :creator_subscription, source: :user
  has_many :subscribers, -> { ChannelSubscription.participant }, through: :channel_subscriptions, source: :user
  has_many :operators, through: :operator_subscriptions, source: :user
  has_many :source_archive_videos, as: :source, class_name: 'ArchiveVideo', dependent: :destroy
  has_and_belongs_to_many :archive_videos
  has_and_belongs_to_many :streams

  # Attributes
  attr_accessor :invited, :user
  alias_attribute :code, :slug
  accepts_nested_attributes_for :channel_subscriptions

  # Validations
  validates :name, presence: true
  validates :user, presence: true, on: :create
  validate  :has_one_creator, on: :update
  validates :slug, presence: true, uniqueness: true, format: { with: /\A[-\w]+\z/, message: 'can only be alphanumeric (no spaces or special characters)' }

  # Callbacks
  before_validation :slugify, on: :create
  before_validation :set_short_url, on: :create
  after_create -> { subscribe_user!(user, ChannelSubscription.valid_roles) }

  # Scopes
  scope :unrestricted, -> { where is_public: true }
  scope :restricted, -> { where is_public: false }

  # @TODO remove after channels are migrated to short_url
  def short_url
    self[:short_url] || Rails.application.routes.url_helpers.channel_watch_url(token, host: Rails.application.config.action_mailer.default_url_options[:host])
  end

  def thumbnail
    source_archive_videos.first.try(:thumbnail)
  end

  def chat_room
    "channel-#{token}"
  end

  def ping
    touch(:last_active_at)
  end

  def current_gps
    output.current_gps if output.is_a?(Stream)
  end

  def host_local
    ::Wowza.channel_info(rtmp_name).fetch('hostLocal') { '' }
  end

  def user_subscribed?(subscriber, role = :participant)
    channel_subscriptions.where(user: subscriber).with_role(role).exists?
  end

  def subscription_available?(subscriber)
    !channel_subscriptions.where(user: subscriber).with_no_role.exists?
  end

  def has_youtube_cdn?
    youtube_rtmp_endpoint.present? && youtube_rtmp_name.present?
  end

  def rtmp
    ::Wowza.generate_watch_deck_rtmp_url rtmp_name
  end

  def hds_url
    "#{ENV['WOWZA_LIVESTREAM_URL']}/channel/#{rtmp_name}/manifest.f4m"
  end

  def hls_url
    "#{ENV['WOWZA_LIVESTREAM_URL']}/channel/#{rtmp_name}/playlist.m3u8"
  end

  def is_live?
    Rails.cache.fetch("Channel_#{token}_is_live", expires_in: 10.seconds) do
      open(hds_url, read_timeout: 2).status[0].to_i == 200 rescue false
    end
  end

  def as_api_json
    as_json(only: %i(id token code name description short_url curate_archive_video created_at updated_at), methods: :code)
  end

  def to_param
    token
  end

  private
    def has_one_creator
      errors.add(:creator, I18n.t('errors.messages.creator')) unless channel_subscriptions.to_a.count { |c| c.is?(:creator) } == 1
    end

    def set_short_url
      self.short_url = BitlyHelper.short_url(Rails.application.routes.url_helpers.channel_watch_url(token, host: Rails.application.config.action_mailer.default_url_options[:host]))
    end
end
