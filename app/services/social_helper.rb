require 'httparty'

class SocialHelper
  include HTTParty
  base_uri 'https://api.cohere.ai/v1'

  DISCLAIMER = "The views expressed are for informational purposes only and do not constitute financial advice. Past performance is no guarantee of future results."

  def self.concatenate_transcript(transcript)
    return nil unless transcript.present?
    transcript.map { |message| message["words"].map { |w| w["text"] }.join(' ') }.join(' ')
  end

  def self.generate_post_from_requirements(transcript_text, requirements)
    return nil unless transcript_text.present? && requirements.present?

    # Prepare the prompt for Cohere
    prompt = <<~PROMPT
      Based on the following requirements, revise the meeting transcript into a social media post:
      
      Requirements:
      #{requirements}
      
      Transcript:
      #{transcript_text}
      
      IMPORTANT: Only use the words and sentences from the transcript provided. Do not invent, add, or summarize with new words, sentences, or paragraphs. Do not include any meta or instructional content such as 'Here is the meeting transcript revised into a social media post' or 'Let me know if there is anything else I can help you with.' Only output the revised post using the transcript content, formatted for social media, with no extra commentary or instructions.
    PROMPT

    response = HTTParty.post(
      "#{base_uri}/generate",
      headers: {
        'Authorization' => "Bearer 4TPgxZDYLk2uUOHaxvGy4UZ489ssGfhLXq0fWNHo",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'command',
        prompt: prompt,
        max_tokens: 400,
        temperature: 0.5,
        k: 0,
        stop_sequences: [],
        return_likelihoods: 'NONE'
      }.to_json
    )

    if response.success?
      post_text = response.parsed_response['generations'][0]['text'].strip
      # Remove any lines that introduce, explain, or instruct about the post or hashtags
      post_text = post_text.lines.reject { |line| line.downcase.include?('hashtag') || line.downcase.include?('here is') || line.downcase.include?('let me know') || line.downcase.include?('anything else i can help') || line.downcase.include?('revised into a social media post') || line.downcase.include?('to revise the transcript') || line.downcase.include?('as requested') || line.downcase.include?('below is') || line.downcase.include?('the following') }.join
      post_text = post_text.gsub(/Here (are|is) (a|some) hashtag(s)?( to encapsulate the meeting)?:/i, '')
      post_text = post_text.gsub(/Hashtags?:/i, '')
      post_text = post_text.gsub(/These hashtags.*?:/i, '')
      post_text = post_text.gsub(/Below (are|is) (a|some) hashtag(s)?.*?:/i, '')
      post_text = post_text.gsub(/Let me know if there is anything else I can help you with.*/i, '')
      post_text = post_text.gsub(/Here is the meeting transcript revised into a social media post.*/i, '')
      post_text = post_text.gsub(/\n+/, "\n")
      post_text = post_text.strip
      hashtags = post_text.scan(/#\w+/).uniq.first(4) # Allow up to 4 hashtags
      post_body = post_text.gsub(/#\w+/, '').strip
      # Remove any trailing punctuation or colons before hashtags
      post_body = post_body.gsub(/[:\-\s]+$/, '').strip

      # Build HTML output
      html = "<span>#{ERB::Util.html_escape(post_body)}</span>"
      html += "<br><br>" if hashtags.any?
      if hashtags.any?
        html += "<span class='social-hashtags' style='color: #3b82f6; font-weight: 500;'>#{hashtags.join(' ')}</span>"
      end
      html += "<br><br>"
      html += "<span class='social-disclaimer' style='font-style: italic; color: #6b7280;'>#{DISCLAIMER}</span>"
      html.html_safe
    else
      Rails.logger.error "Failed to generate social post: #{response.body}"
      nil
    end
  end

  def self.generate_post(transcript, platform: 'linkedin')
    return nil unless transcript.present?

    transcript_text = concatenate_transcript(transcript)

    # Prepare the prompt for Cohere
    prompt = <<~PROMPT
      Revise the following meeting transcript into a single, first-person, warm, conversational social media post suitable for a financial advisor on #{platform.capitalize}. Summarize the value of the meeting. At the end, suggest 3 relevant hashtags based on the transcript (no more than 3, no duplicates, no special characters except #, and each hashtag should be a single word or camel case). Do not include introductory or closing remarks outside the post. Do not mention the meeting title. Do not include any lines like 'Let me know if you would like me to adjust anything else.' Do not explain or introduce the hashtags, just list them at the end.
      
      Transcript:
      #{transcript_text}
    PROMPT

    response = HTTParty.post(
      "#{base_uri}/generate",
      headers: {
        'Authorization' => "Bearer 4TPgxZDYLk2uUOHaxvGy4UZ489ssGfhLXq0fWNHo",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'command',
        prompt: prompt,
        max_tokens: 400,
        temperature: 0.5,
        k: 0,
        stop_sequences: [],
        return_likelihoods: 'NONE'
      }.to_json
    )

    if response.success?
      post_text = response.parsed_response['generations'][0]['text'].strip
      # Remove any lines that introduce or explain hashtags
      post_text = post_text.lines.reject { |line| line.downcase.include?('hashtag') }.join
      post_text = post_text.gsub(/Here (are|is) (a|some) hashtag(s)?( to encapsulate the meeting)?:/i, '')
      post_text = post_text.gsub(/Hashtags?:/i, '')
      post_text = post_text.gsub(/These hashtags.*?:/i, '')
      post_text = post_text.gsub(/Below (are|is) (a|some) hashtag(s)?.*?:/i, '')
      post_text = post_text.gsub(/\n+/, "\n")
      post_text = post_text.strip
      hashtags = post_text.scan(/#\w+/).uniq.first(3)
      post_body = post_text.gsub(/#\w+/, '').strip
      # Remove any trailing punctuation or colons before hashtags
      post_body = post_body.gsub(/[:\-\s]+$/, '').strip

      # Build HTML output
      html = "<span>#{ERB::Util.html_escape(post_body)}</span>"
      html += "<br><br>" if hashtags.any?
      if hashtags.any?
        html += "<span class='social-hashtags' style='color: #3b82f6; font-weight: 500;'>#{hashtags.join(' ')}</span>"
      end
      html += "<br><br>"
      html += "<span class='social-disclaimer' style='font-style: italic; color: #6b7280;'>#{DISCLAIMER}</span>"
      html.html_safe
    else
      Rails.logger.error "Failed to generate social post: #{response.body}"
      nil
    end
  end

  def self.create_and_generate_post(transcript, platform: 'linkedin')
    content = generate_post(transcript, platform: platform)
    return nil unless content.present?
    SocialPost.create(platform: platform, content: content)
  end
end 