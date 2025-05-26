require 'httparty'

class EmailGeneratorService
  include HTTParty
  base_uri 'https://api.cohere.ai/v1'

  def self.generate_email(transcript, title, user)
    return nil unless transcript.present?

    if transcript.is_a?(Array) && transcript.first.is_a?(Hash) && transcript.first.key?("words")
      # If transcript is already in the expected format, just concatenate the words
      transcript_text = transcript.map { |message| message["words"].map { |w| w["text"] }.join(' ') }.join(' ')
      
      # Use \r\n for better compatibility or add extra line breaks
      email_body = "Subject: Follow-up: #{title}\r\n\r\n" \
        + "Good day,\r\n\r\n" \
        + "Based on our conversation, we discussed...\r\n\r\n" \
        + transcript_text + "\r\n\r\n" \
        + "Best regards,\r\n\r\n" \
        + "#{user.first_name.capitalize} #{user.last_name.capitalize}"
      return email_body
    end

    # Extract text from transcript
    transcript_text = transcript.map { |message| 
      "#{message['speaker']}: #{message['words'].map { |w| w['text'] }.join(' ')}"
    }.join("\n")

    # Prepare the prompt for Cohere
    prompt = <<~PROMPT
      Clean up and make this meeting transcript more readable for an email. Keep the speaker labels but make the text flow better. Do not add any introductory or closing remarks. Do not mention the meeting title. Do not include any lines like 'I hope that was helpful! Let me know if you would like me to adjust anything else.'
      
      Transcript:
      #{transcript_text}
    PROMPT

    # Make API call to Cohere
    response = HTTParty.post(
      "#{base_uri}/generate",
      headers: {
        'Authorization' => "Bearer 4TPgxZDYLk2uUOHaxvGy4UZ489ssGfhLXq0fWNHo",
        'Content-Type' => 'application/json'
      },
      body: {
        model: 'command',
        prompt: prompt,
        max_tokens: 1000,
        temperature: 0.3,
        k: 0,
        stop_sequences: [],
        return_likelihoods: 'NONE'
      }.to_json
    )

    if response.success?
      # Extract the generated text from the response
      cleaned_text = response.parsed_response['generations'][0]['text']
      
      # Remove unwanted lines if present
      cleaned_text = cleaned_text.gsub(/^Sure,? here is (a )?cleaned[- ]?up version of (the )?meeting transcript:?.*$/i, '')
      cleaned_text = cleaned_text.gsub(/<br\s*\/?\s*>/i, "\n")
      cleaned_text = cleaned_text.gsub(/Sure, here is the transcript cleaned up to be more readable for an email:\s*/i, '')
      cleaned_text = cleaned_text.gsub(/Meeting Title:.*\n?/i, '')
      cleaned_text = cleaned_text.gsub(/I hope that was helpful! Let me know if you would like me to adjust anything else\.?/i, '')
      cleaned_text = cleaned_text.gsub(/^.*cohere.*$/i, '')
      cleaned_text = cleaned_text.gsub(/^.*AI (dashboard|summary|transcript|version|process|generated|cleaned).*$/i, '')
      cleaned_text = cleaned_text.gsub(/^.*(cleaned|summarized|version|generated|AI).*transcript.*$/i, '')
      # Remove speaker names (e.g., 'Miguel Jump:')
      cleaned_text = cleaned_text.gsub(/^\s*\w[\w\s\.\-']{1,40}:\s*/m, '')
      cleaned_text = cleaned_text.strip
      
      # Format without subject line:
      # - Good day (at very top)
      # - Good day + single enter  
      # - Based on conversation + single enter
      # - Email body + double enter
      # - Best regards + single enter
      # - Name
      email_body = "Good day,\n" \
        + "Based on our conversation, we discussed...\n" \
        + cleaned_text + "\n\n" \
        + "Best regards,\n" \
        + "#{user.first_name.capitalize} #{user.last_name.capitalize}"
      
      # Debug: Log the email content to see what's being generated
      Rails.logger.info "Generated email body: #{email_body.inspect}"
      Rails.logger.info "Cleaned text: #{cleaned_text.inspect}"
      email_body
    else
      Rails.logger.error "Failed to generate email: #{response.body}"
      nil
    end
  end
end