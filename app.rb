# coding: utf-8
require 'active_support/core_ext/numeric/time'
require 'rufus-scheduler'
require 'mastodon'
require_relative 'db_funcs'
require_relative 'rm_constants'

=begin
 TODO:
  add way to cancel commands
  (set up a hash table with the toot id being the uid of the job?
   if a user replies to that receipt toot with 'cancel' we just cancel the job
   confirm to the user that the toot has been deleted and then remove it from the hash
  )
  add support for message like "@RemindMe tomorrow to ~whatever~"

  fix messages with mentions leaving the mention in the message. (it tacks all mentions onto
   the beginning, leaving the @username sans instance in the body of the message)

  fix issue where if a user inputs a time (11:30) and it's meant to be tomorrow it runs the alert
   immediatly instead of scheduling it properly

=end

#
# Set message function for parsing/building replies
#

def parse_message input_toot
  # vv strips the html tags and the bot's name from the message text
  input = input_toot.status.content.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, '').gsub(/@#{MASTO_CONFIG[:acct]}/, '').chomp

  print input
  
  reply_content = ''
  time_wanted = Time.zone.now # get current time


  
  case input

  # when we see that the user may have used shorthand :/
  when MisspellRegexp
    build_post_reply input_toot, ErrorMisspellMessage


  # if we see a command we should run it
  when CommandRegexp
    errored = true # we set this flag so we don't accidentally schedule our command
    
    match = CommandRegexp.match(input)

    case match[:tCommand]

    when 'cancel'
      parent = RestClient.status(input_toot.status.in_reply_to_id)
      if cancel_scheduled parent.in_reply_to_id, input_toot.account.acct
        build_post_reply input_toot, CancelApproveMessage
      else
        build_post_reply input_toot, CancelDenyMessage
      end

    when 'help'
      build_post_reply input_toot, HelpMessage

      
    end
        

    
  # when we match the relative regexp
  when RelativeRegexp
    match = input.scan(RelativeRegexp)
    
    match.each do |m|
      m.each { |subOut|
        input.sub!(subOut, '') unless subOut.nil?  # go ahead and remove time string from input
      }
      time_wanted += m[1].to_i.send(m[2]) # add up the times into the current
    end

    errored = false

    
  # when we match the absolute regexp
  when AbsoluteRegexp
    match = AbsoluteRegexp.match(input) # get the match data for removing
    match_ar = match.to_a; match_ar.shift # go ahead and turn it into an array for easy looping (and remove base input)
    
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
    build_post_reply input_toot, AppreciationMessage
    errored = true # this is to sneak past the check down below so we don't send a few extra messages ;P
    
  else
    # if we get here then that means we didn't match any regexp
    #  and that makes us sad :(
    errored = true
    build_post_reply input_toot, ErrorMessage
  end
  
  if not errored
    reply_content = build_reply(input_toot.status, input_toot.account.acct, input.lstrip.chomp)
    
    job = Scheduler.at time_wanted.localtime, :job => true do
      post_reply(reply_content, input_toot.status.visibility, input_toot.status.id)
      remove_scheduled input_toot.status.id
    end

    write_db_data(time_wanted,
                  input_toot.status.id,
                  reply_content,
                  input_toot.status.visibility,
                  input_toot.account.acct,
                  job.id)
    $schedule_jobs[job.id] = job
    
    build_post_reply input_toot, MessageReceipt
  end
end

                                                                   
#
#  helper functions
#

def reschedule_toot(time, reply_id, text, visibility)
  job = Scheduler.at time.localtime, :job => true do
    post_reply(text, visibility, reply_id)
    remove_scheduled reply_id
  end

  $schedule_jobs[job.id] = job
end
                                                                   
def build_reply status, acct, text
  # build a string out of the mentions (may remove later)
  mentions = status.mentions.to_a.map! { |m|
    "@#{m.acct}" unless m.acct == MASTO_CONFIG[:acct]
  }.join ' '

  # build up the actual content of the message
  %(@#{acct} #{mentions}
#{MessageArray.include?(text) ? '' : Header}

#{text}

#{text == MessageReceipt ? "Your reminder receipt is: #{1 + Random.rand(10000000000000) / Time.zone.now.to_i}" : ''})
end


def build_post_reply toot, text
  post_reply(build_reply(toot.status, toot.account.acct, text),
             toot.status.visibility,
             toot.status.id)
end


def post_reply text, visibility, reply_to

  options = {

    visibility: visibility,
    in_reply_to_id: reply_to,
#    spoiler_text: toot.status.spoiler_text || ''   <- doesn't work in mastodon-api as of right now

  }
  
  RestClient.create_status text, options
end

#
# set up a loop to catch mentions
#

#load up old toots
load_from_db

StreamClient.user do |toot|
  next unless toot.kind_of? Mastodon::Notification
  next unless toot.type == 'mention'

  parse_message toot
end
