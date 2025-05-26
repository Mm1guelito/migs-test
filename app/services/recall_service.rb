require 'net/http'
require 'json'
require 'httparty'

class RecallService
  BASE_URL = "https://#{ENV['RECALL_REGION']}.recall.ai/api/v1"
  
  # Enhanced bot creation with comprehensive configuration options
  def self.create_bot(meeting_url, options = {})
    uri = URI("#{BASE_URL}/bot")
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Token #{ENV['RECALL_API_KEY']}"
    request['Content-Type'] = 'application/json'
    
    # Default configuration with improved recording settings
    bot_config = {
      meeting_url: meeting_url,
      bot_name: options[:bot_name] || "Meeting Notetaker",
      
      # Reduce recording delay by starting immediately on call join
      start_recording_on: "call_join",
      
      # Optimize recording mode for performance
      recording_mode: options[:recording_mode] || "speaker_view",
      recording_mode_options: {
        participant_video_when_screenshare: "hide"
      },
      
      # Enhanced transcription options
      transcription_options: { 
        provider: options[:transcription_provider] || "meeting_captions"
      },
      
      # Configure automatic leave timeouts
      automatic_leave: {
        waiting_room_timeout: options[:waiting_room_timeout] || 1200,
        noone_joined_timeout: options[:noone_joined_timeout] || 1200,
        everyone_left_timeout: options[:everyone_left_timeout] || 2,
        in_call_not_recording_timeout: options[:in_call_not_recording_timeout] || 3600
      },
      
      # Add real-time transcription if webhook URL provided
      real_time_transcription: build_real_time_config(options[:webhook_url])
    }.compact
    
    request.body = bot_config.to_json

    log_request("create_bot", uri, request)
    
    response = make_http_request(uri, request)
    handle_api_response(response, "create_bot")
  end

  # Enhanced bot status with polling capability
  def self.get_bot_status(bot_id)
    uri = URI("#{BASE_URL}/bot/#{bot_id}")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Token #{ENV['RECALL_API_KEY']}"
    
    log_request("get_bot_status", uri, request)
    
    response = make_http_request(uri, request)
    handle_api_response(response, "get_bot_status")
  end

  # Wait for bot to complete with status monitoring
  def self.wait_for_bot_completion(bot_id, max_wait_time = 1800)
    start_time = Time.now
    
    loop do
      if Time.now - start_time > max_wait_time
        raise "Bot completion timeout after #{max_wait_time} seconds"
      end
      
      status_response = get_bot_status(bot_id)
      current_status = status_response.dig('status_changes')&.last&.dig('code')
      
      Rails.logger.info "Bot #{bot_id} status: #{current_status}"
      
      case current_status
      when 'done'
        Rails.logger.info "Bot #{bot_id} completed successfully"
        return status_response
      when 'call_ended'
        Rails.logger.info "Call ended for bot #{bot_id}, waiting for processing..."
      when 'error', 'fatal'
        error_message = status_response.dig('status_changes')&.last&.dig('message') || 'Unknown error'
        raise "Bot #{bot_id} encountered an error: #{error_message}"
      when 'joining_call'
        Rails.logger.info "Bot #{bot_id} is joining the call..."
      when 'in_waiting_room'
        Rails.logger.info "Bot #{bot_id} is in waiting room..."
      end
      
      sleep(5)
    end
  end

  # Enhanced transcript retrieval with diarization options
  def self.get_transcript(bot_id, options = {})
    uri = URI("#{BASE_URL}/bot/#{bot_id}/transcript")
    
    # Add query parameters for enhanced features
    query_params = []
    query_params << "enhanced_diarization=true" if options[:enhanced_diarization]
    uri.query = query_params.join('&') unless query_params.empty?
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Token #{ENV['RECALL_API_KEY']}"
    
    log_request("get_transcript", uri, request)
    
    response = make_http_request(uri, request)
    handle_api_response(response, "get_transcript")
  end

  # Get recording URL for download
  def self.get_recording(bot_id)
    uri = URI("#{BASE_URL}/bot/#{bot_id}")
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Token #{ENV['RECALL_API_KEY']}"
    
    response = make_http_request(uri, request)
    bot_data = handle_api_response(response, "get_recording")
    
    {
      video_url: bot_data.dig('video_url'),
      audio_url: bot_data.dig('audio_url'),
      chat_messages: bot_data.dig('chat_messages')
    }
  end

  # Create bot with audio-only mode for better performance
  def self.create_audio_only_bot(meeting_url, options = {})
    create_bot(meeting_url, options.merge(
      recording_mode: "audio_only",
      bot_name: options[:bot_name] || "Audio Notetaker"
    ))
  end

  private

  def self.build_real_time_config(webhook_url)
    return nil unless webhook_url
    
    {
      destination_url: webhook_url,
      partial_results: true
    }
  end

  def self.make_http_request(uri, request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.read_timeout = 30
      http.open_timeout = 30
      http.request(request)
    end
  rescue Net::TimeoutError => e
    Rails.logger.error "HTTP timeout for #{uri}: #{e.message}"
    raise "API request timeout: #{e.message}"
  rescue => e
    Rails.logger.error "HTTP error for #{uri}: #{e.message}"
    raise "API request failed: #{e.message}"
  end

  def self.handle_api_response(response, method_name)
    case response.code.to_i
    when 200..299
      JSON.parse(response.body)
    when 400
      error_data = JSON.parse(response.body) rescue {}
      Rails.logger.error "Bad request in #{method_name}: #{error_data}"
      raise "Bad request: #{error_data['message'] || response.body}"
    when 401
      Rails.logger.error "Unauthorized in #{method_name}"
      raise "Invalid API key or unauthorized access"
    when 404
      Rails.logger.error "Not found in #{method_name}"
      raise "Resource not found"
    when 429
      Rails.logger.error "Rate limited in #{method_name}"
      raise "Rate limit exceeded, please try again later"
    when 500..599
      Rails.logger.error "Server error in #{method_name}: #{response.code}"
      raise "Server error: #{response.code}"
    else
      Rails.logger.error "Unexpected response in #{method_name}: #{response.code}"
      raise "Unexpected response: #{response.code}"
    end
  rescue JSON::ParserError => e
    Rails.logger.error "JSON parsing error in #{method_name}: #{e.message}"
    Rails.logger.error "Response body: #{response.body}"
    raise "Invalid JSON response: #{e.message}"
  end

  def self.log_request(method_name, uri, request)
    Rails.logger.info "#{method_name}: Making API request to #{uri}"
    Rails.logger.debug "#{method_name}: Request body: #{request.body}" if request.body
    Rails.logger.debug "#{method_name}: Authorization: Token #{ENV['RECALL_API_KEY']&.slice(0, 8)}..."
  end
end 