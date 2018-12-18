# coding: utf-8
require 'active_support/core_ext/numeric/time'
require 'rufus-scheduler'
require 'elephrame'
require_relative 'helpers'
require_relative 'db_funcs'
require_relative 'rm_constants'

=begin
 TODO:
  (set up a hash table with the toot id being the uid of the job?
   if a user replies to that receipt toot with 'cancel' we just cancel the job
   confirm to the user that the toot has been deleted and then remove it from the hash
  )  <- may be a better way to do it, seeing as how I didn't actually implement this

  add support for message like "@RemindMe tomorrow to ~whatever~"

  fix messages with mentions leaving the mention in the message. (it tacks all mentions onto
   the beginning, leaving the @username sans instance in the body of the message)

=end


# adds cancel command
RemindMe.add_command 'cancel' do |bot, data, status|
  receipt = bot.find_ancestor(status.id, 2)
  
  if cancel_scheduled(receipt.in_reply_to_id,
                      receipt.account.acct)
    bot.reply(CancelApproveMessage)
  else
    bot.reply(CancelDenyMessage)
  end
end


# adds until command
RemindMe.add_command 'until' do |bot, data, status|
  receipt = bot.find_ancestor(status.id, 3)
  
  unless reciept.nil?
    # get the jobid from our db and retrieve our job from the
    #  schedule_jobs hash
    jobid = get_jobid(receipt.in_reply_to_id)
    o_job = $schedule_jobs.select { |k, v|
      k == jobid
    }[jobid]
    
    # if we actually found the job
    if not o_job.nil?
      # o_job.original is the time we scheduled the post
      # returns the number of seconds until the scheduled post fires
      hours_until = ((o_job.original -
                      Time.zone.now.localtime) / 3600).to_i # convert to int to strip frac
      mins_until  = (((o_job.original -
                       Time.zone.now.localtime) / 3600) % 1 * 60).round
      
      # reply with a message telling them how long until their reminder!
      if mins_until > 0 || hours_until > 0
        
        rsp = ""
        
        # because english is a fuck
        if hours_until > 0
          rsp += "#{hours_until} hour#{hours_until > 1 ? 's' : ''}"
        end
        
        if mins_until > 0
          rsp += " #{mins_until} minute#{mins_until > 1 ? 's' : ''}"
        end
        
        bot.reply(UntilMessage + rsp)
      else
        bot.reply(UntilMessage + 'less than a minute!')
      end
    else
      puts 'could not find job :shrug:'
    end
  end
end


RemindMe.run do |bot, status|
  # vv strips the html tags and the bot's name from the message text
  input = status.content.gsub(/@#{bot.username}/, '').strip
  
  reply_content = ''
  time_wanted = Time.zone.now # get current time

  
  case input

  # when we see that the user may have used shorthand :/
  when MisspellRegexp
    bot.reply(ErrorMisspellMessage)

    
  # when we match the relative regexp
  when RelativeRegexp
    match = input.scan(RelativeRegexp)

    match.each do |m|
      m.each { |subOut|
        input.sub!(subOut.split[0], '') unless subOut.nil?  # go ahead and remove time string from input
      }

      time_wanted += m[1].to_i.send(m[2]) # add up the times into the current
    end

    errored = false

    
  # when we match the absolute regexp
  when AbsoluteRegexp
    match = AbsoluteRegexp.match(input) # get the match data for removing
    # go ahead and turn it into an array for
    #  easy looping (and remove base input)
    match_ar = match.to_a; match_ar.shift 
    
    match_ar.each do |m|
      input.sub!(m, '') unless m.nil? # remove string from input
    end
    input.gsub!(/^(\s+)?:+/, '')

    # build the time string 
    time_wanted = Time.zone.parse("#{match[:tHours]}:#{match[:tMinutes] || 00}:#{match[:tSeconds] || 00}#{match[:tAPM] || ''} #{match[:TZ]}")

    time_wanted += 1.day if Time.zone.now > time_wanted

    errored = false

    
  # if someone says thanks then we should respond :3
  when ThanksRegexp
    bot.reply(AppreciationMessage)

    # this is to sneak past the check down below so we don't
    #  send a few extra messages ;P
    errored = true 
    
  else
    # if we get here then that means we didn't match any regexp
    #  and that makes us sad :(
    bot.reply(ErrorMessage)
    errored = true
  end
  
  if not errored
    reply_content = build_reply(status, %(#{Header}

    #{input}))
    
    reciept_msg = %(#{MessageReceipt}
Your reminder receipt is: #{1 + Random.rand(1000000000000) / Time.zone.now.to_i}

#{ReceiptCommandInfo})
    
    job = Scheduler.at time_wanted.localtime, :job => true do
      RemindMe.post(reply_content,
                    visibility: status.visibility,
                    reply_id: status.id)
      remove_scheduled status.id
    end

    write_db_data(time_wanted,
                  status.id,
                  reply_content,
                  status.visibility,
                  status.account.acct,
                  job.id)
    $schedule_jobs[job.id] = job
    
    bot.reply_with_mentions(build_reply(nil, reciept_msg))
  end
end
