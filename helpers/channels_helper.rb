module ChannelsHelper
  def channel_embed_code(source, width = 560, height = 315)
    url = source.is_a?(Channel) ? source.short_url : source.url
    "<iframe width='#{width}' height='#{height}' src='#{url}' frameborder='0' allowfullscreen></iframe>"
  end

  def format_name(name)
    if name =~ /\Auser-/
      name.to_s.sub(/\Auser-/, '').to_s.humanize + "'s Channel"
    else
      name
    end
  end

  def channel_thumb(source)
    source.image_tmp.present? || source.image.url.blank? ? 'channel_thumbnail_v100x60.jpg' : source.image.send(:v100x60).url
  end

end
