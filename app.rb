# coding: utf-8
require 'active_support/core_ext/numeric/time'
require 'rufus-scheduler'
require 'mastodon'

=begin
 TODO:
  add db funcs
  add way to cancel commands
  (set up a hash table with the toot id being the uid of the job?
   if a user replies to that reciept toot with 'cancel' we just cancel the job
   confirm to the user that the toot has been deleted and then remove it from the hash
  )
  add support for message like "@RemindMe tomorrow to ~whatever~"

=end

#
# Set up constants
#

MASTO_CONFIG = {
  access: ENV['BEARER'],
  acct: ENV['ACCT'],
  instance: ENV['INSTANCE']
}

RestClient = Mastodon::REST::Client.new(base_url: MASTO_CONFIG[:instance],
                                      bearer_token: MASTO_CONFIG[:access])
StreamClient = Mastodon::Streaming::Client.new(base_url: MASTO_CONFIG[:instance],
                                             bearer_token: MASTO_CONFIG[:access])

Time.zone = 'UTC'
Scheduler = Rufus::Scheduler.new
TimeWordMisspell = [ 'hr', 'min', 'sec', 'wk' ]
TimeMisspellString = '('+ TimeWordMisspell.join('|') + ')s?\b'
TimeWords = [ 'hour', 'minute', 'day', 'second', 'week'] 
TimeString = '('+ TimeWords.join('|') + ')s?\b'

#
# compiles the regexes for later use
#
MisspellRegexp = Regexp.new(/
#{TimeMisspellString}
/ix)
RelativeRegexp = Regexp.new(/
(?<tWord>in)?                    # catch the word
\s?                              # more whitespace
((?<tNumber>[[:digit:]]+)         # get how many ever numbers
\s                                # space
(?<tInterval>#{TimeString}))+/ix) # any word matched by the words in TimeWords
AbsoluteRegexp = Regexp.new(/
(?<tWord>at)?                 # catches the word to remove
\s?                           # more whitespace
(?<tHours>[[:digit:]]+):       # gets the hours
(?<tMinutes>[[:digit:]]{2})(:  # gets the minutes
(?<tSeconds>[[:digit:]]{2}))?  # gets seconds, if it's there
\s?                            # in case the input is HH:MM PM instead of HH:MMPM
(?<tAPM>(A|P)M)?               # same for AM\PM
\s?                            # white space
(?<TZ>[[:alpha:]]{3})?/ix)     # gets timezone if it's there

#
# post-related messages
#
Header = %(⏰* REMINDER *⏰)
ErrorMessage = %(Sorry, I didn't understand that :/

I understand formats like: 

- 1 minute 30 seconds Hello!
- 16:20 EDT blaze it
- at 6:30:30 UTC get dinner
- in 3 hours 30 minutes feed dog)
ErrorMisspellMessage = %(It looks like you may have tried to abbreviate a time specification (e.g., 'minutes' to 'min', 'seconds' to 'sec')

I actually can't parse that out so please use the full spelling of the word. Please and thank you!)
MessageReciept = %(I'll try to remind you then!)


#
# Sets message functions for parsing/building replies
#

def parse_message input_toot
  # vv strips the html tags and the bot's name from the message text
  input = input_toot.status.content.gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, '').gsub(/@#{MASTO_CONFIG[:acct]}/, '').chomp
  
  
  case input

  # when we see that the user may have used shorthand :/
  when MisspellRegexp
    build_post_reply input_toot, ErrorMisspellMessage

    
  # when we match the relative regexp
  when RelativeRegexp
    match = input.scan(RelativeRegexp)
    t = Time.zone.now # get current time
    
    match.each do |m|
      m.each { |subOut|
        input.sub!(subOut, '') unless subOut.nil?  # go ahead and remove time string from input
      }
      t += m[1].to_i.send(m[2]) # add up the times into the current
    end

    Scheduler.at t.localtime do # schedule 
      build_post_reply input_toot, input.lstrip.chomp # lstrip to remove leading whitespace
    end
    build_post_reply input_toot, MessageReciept    

    
  # when we match the absolute regexp
  when AbsoluteRegexp
    match = AbsoluteRegexp.match(input) # get the match data for removing
    match_ar = match.to_a; match_ar.shift # go ahead and turn it into an array for easy looping (and remove base input)
    
    match_ar.each do |m|
      input.sub!(m, '') unless m.nil? # remove string from input
    end
    input.gsub!(/^(\s+)?:+/, '')

    # build the time string 
    time_str = "#{match[:tHours]}:#{match[:tMinutes] || 00}:#{match[:tSeconds] || 00}#{match[:tAPM] || ''} #{match[:TZ]}"
    
    Scheduler.at Time.zone.parse(time_str).localtime do # parse it into a real time object and schedule
       build_post_reply input_toot, input.lstrip.chomp
    end
    
    build_post_reply input_toot, MessageReciept
  else
    # if we get here then that means we didn't match any regexp
    #  and that makes us sad :(
    build_post_reply input_toot, ErrorMessage
 end
end

def build_post_reply toot, text

  # build a string out of the mentions (may remove later)
  mentions = toot.status.mentions.to_a.map! { |m|
    "@#{m.acct}" unless m.acct == MASTO_CONFIG[:acct]
  }.join ' '

  # build up the actual content of the message
  text = %(@#{toot.account.acct} #{mentions}
#{/(#{ErrorMessage})|(#{MessageReciept})|(#{ErrorMisspellMessage})/.match(text) ? '' : Header}

#{text})

  options = {

    visibility: toot.status.visibility,
    in_reply_to_id: toot.status.id,
#    spoiler_text: toot.status.spoiler_text || ''   <- doesn't work in mastodon-api as of right now

  }
  
  RestClient.create_status text, options
  
end

#
# set up a loop to catch mentions
#

StreamClient.user do |toot|
  next unless toot.kind_of? Mastodon::Notification
  next unless toot.type == 'mention'

  parse_message toot
end
