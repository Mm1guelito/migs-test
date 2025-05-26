namespace :recall do
  desc "Check all pending recall events"
  task check_pending: :environment do
    puts "Checking all pending recall events..."
    CheckRecallStatusJob.perform_async
    puts "Done scheduling checks for pending events"
  end
end 