module Api
  module V1
    class ChannelsController < BaseSessionController
      before_action :authenticate_user!, only: [:create, :update]
      before_action :ensure_current_user!, only: :subscribe
      before_action :ensure_channel_found!, only: :update
      before_action :ensure_channels_found!, only: :subscribe
      before_action :ensure_user_subscription_available!, only: :subscribe

      def create
        begin
          channel = Channel.create! channel_params.merge(user: current_user)
        rescue *RecoverableExceptions => e
          return error(E_INTERNAL, e.message)
        end

        success(channels: channel.reload.as_api_json)
      end

      def update
        authorize! :update, @channel

        begin
          @channel.update! channel_params
        rescue *RecoverableExceptions => e
          return error(E_INTERNAL, e.message)
        end

        success(channels: @channel.reload.as_api_json)
      end

      def subscribe
        begin
          @channels.each do |channel|
            channel.subscribe_user! current_user, ChannelSubscription.sanitize_roles(channel_subscribe_params[:channel_subscriptions][:roles], ChannelSubscription.default_roles)
          end
        rescue *RecoverableExceptions => e
          Bugsnag.notify(e)
          return error(E_INTERNAL, e.message)
        end

        success(channels: @channels.map { |channel| { id: channel.id, token: channel.token, code: channel.slug, name: channel.name, short_url: channel.short_url, is_public: channel.is_public? } })
      end

      private
        def ensure_channel_found!
          @channel = Channel.find_by token: params[:token]
          return error(E_RESOURCE_NOT_FOUND, I18n.t('api.errors.channel_not_found')) if @channel.blank?
        end

        def ensure_channels_found!
          @channels = if channel_subscribe_params[:tokens].present?
            Channel.where token: channel_subscribe_params[:tokens]
          elsif channel_subscribe_params[:codes].present?
            Channel.where slug: channel_subscribe_params[:codes]
          end
          return error(E_RESOURCE_NOT_FOUND, I18n.t('api.errors.channel_not_found')) if @channels.blank?
        end

        def ensure_user_subscription_available!
          @channels.each do |channel|
            return error E_ACCESS_DENIED, I18n.t('api.errors.channel_subscription_not_available') unless channel.subscription_available?(current_user)
          end
        end

        def channel_subscribe_params
          params.require(:channels).permit codes: [], tokens: [], channel_subscriptions: { roles: [] }
        end

        def channel_params
          params.require(:channels).permit :name, :description, :curate_archive_video
        end
    end
  end
end
