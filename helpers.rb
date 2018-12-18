#
#  helper functions
#

def reschedule_toot(time, reply_id, text, visibility, job_id)
  if time.is_a? String
    time = ActiveSupport::TimeZone['UTC'].parse(time)
  end

  job = Scheduler.at time.localtime, :job => true do
    RemindMe.post(text,
                  visibility: visibility,
                  reply_id: reply_id)
    remove_scheduled reply_id
  end

  $schedule_jobs[job_id] = job
end
                                                                   
def build_reply status, text
  # build a string out of the mentions (may remove later)
  mentions = status.mentions.to_a.map! { |m|
    "@#{m.acct}" unless m.acct == RemindMe.username
  }.join ' '.strip unless status.nil?
  
  # build up the actual content of the message
  %(#{status.nil? ? '' : "@#{status.account.acct} #{mentions}"}

#{text})
end
