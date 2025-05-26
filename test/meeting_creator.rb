require_relative '../config/environment'

# Create a test meeting
meeting = CalendarEvent.create!(
  title: "Test Meeting with Recall Bot",
  unique_id: "test_meeting_#{Time.current.to_i}",
  start_time: 1.minute.from_now,
  end_time: 31.minutes.from_now,
  timezone: "UTC",
  organizer: "migueljump01@gmail.com",
  description: "Testing Recall.ai integration",
  attendees: ["migueljump01@gmail.com"],
  meeting_url: "https://meet.google.com/iug-udkw-psk",
    bot_join: true,
  bot_time: 1,
  user_id: 1,
  google_account_id: 1
)

puts "Created test meeting:"
puts "Title: #{meeting.title}"
puts "Start time: #{meeting.start_time}"
puts "Meeting URL: #{meeting.meeting_url}"
puts "Bot will join #{meeting.bot_time} minute before the meeting"

# Create the bot immediately
puts "\nCreating Recall bot..."
begin
  response = RecallService.create_bot(meeting.meeting_url)
  puts "API Response: #{response.inspect}"
  
  if response["id"].present?
    puts "Bot created with ID: #{response['id']}"
    # Update the meeting with the bot ID
    meeting.update!(recall_bot_id: response['id'])
    puts "Meeting updated with bot ID"

    # Check bot status
    puts "\nChecking bot status..."
    status = RecallService.get_bot_status(response['id'])
    puts "Status Response: #{status.inspect}"
    
    if status["status_changes"].present?
      puts "Bot status: #{status['status_changes'].last['code']}"
    else
      puts "No status changes found in response"
    end
  else
    puts "Error: No bot ID in response"
  end
rescue => e
  puts "Error creating bot: #{e.message}"
  puts e.backtrace
end 