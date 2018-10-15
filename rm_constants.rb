# coding: utf-8
#
# Set up constants
#

RestClient = Mastodon::REST::Client.new(base_url: ENV['INSTANCE'],
                                      bearer_token: ENV['BEARER'])
StreamClient = Mastodon::Streaming::Client.new(base_url: ENV['INSTANCE'],
                                             bearer_token: ENV['BEARER'])

MASTO_CONFIG = {
  access: ENV['BEARER'],
  acct: RestClient.verify_credentials().acct,
  instance: ENV['INSTANCE']
}

Time.zone = 'UTC'
Scheduler = Rufus::Scheduler.new
DB_Client = db_from_file
TimeWordMisspell = [ 'hr', 'min', 'sec', 'wk' ]
TimeMisspellString = '('+ TimeWordMisspell.join('|') + ')s?\b'
TimeWords = [ 'hour', 'minute', 'day', 'second', 'week', 'tomorrow(?<tTmRel>\s(morning|afternoon|evening))?'] 
TimeString = '('+ TimeWords.join('|') + ')s?\b'
CommandWords = [ 'cancel', 'help' ]
CmdString = '!(?<tCommand>' + CommandWords.join('|') + ')'

$schedule_jobs = {}

#
# compiles the regexes for later use
#
MisspellRegexp = Regexp.new(/
#{TimeMisspellString}
/ix)

RelativeRegexp = Regexp.new(/
((?<tWord>in?\s)?
(?<tNumber>[[:digit:]]+)\s)?         
(?<tInterval>#{TimeString})+/ix) # any word matched by the words in TimeWords
AbsoluteRegexp = Regexp.new(/
(?<tWord>at)?                 # catches the word to remove
\s?                           # more whitespace
(?<tHours>[[:digit:]]+):       # gets the hours
(?<tMinutes>[[:digit:]]+)(:  # gets the minutes
(?<tSeconds>[[:digit:]]+))?  # gets seconds, if it's there
\s?                            # in case the input is HH:MM PM instead of HH:MMPM
(?<tAPM>(A|P)M)?               # same for AM\PM
\s?                            # white space
(?<TZ>[[:alpha:]]{3+})?/ix)     # gets timezone if it's there
CommandRegexp = Regexp.new(/
.* #{CmdString} .*
/ix)
ThanksRegexp = Regexp.new(/
\s+(thanks?( you)?)
/xi)
                               
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
MessageReceipt = %(I'll try to remind you then!)
CancelApproveMessage = %(Your reminder has been canceled!)
CancelDenyMessage = %(Oh no, I couldn't cancel that reminder :/

If you believe this to be in error please try again by replying to the reminder confirmation toot with !cancel)
HelpMessage = %(I have two ways for you to use me, relative and absolute:
1- in 45 minutes feed dog
2- at 16:20 EDT blaze it

(pst: you don't need 'in' or 'at' either!)

if using #1 I recognize minutes, seconds, hours, days and weeks
if using #2 I need at least hours, and at most HH:MM:SS. but I always need a 3 letter timezone (defaults to UTC)

If you want to cancel a reminder just reply to the message receipt with !cancel
however only you can cancel your own reminder!)
AppreciationMessage = %(No problem :3)

MessageArray = [ ErrorMessage, ErrorMisspellMessage, MessageReceipt,
                 CancelDenyMessage, CancelApproveMessage, HelpMessage,
                 AppreciationMessage
               ]

