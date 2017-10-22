# RemindMeBot

This is a complete reworking of the original RemindMe bot I made using python (hosted over [here](https://botsin.space/@RemindMe))

I feel like this bot will be better able to parse messages and scheduling replies

Feel free to contribute if you want!

# Running personal version

To run the bot you need to specify an instance, a mastodon access token, and the username of the bot on the command line

Something like:
```bash
BEARER='your_access_token_here' ACCT='BotNameHere' INSTANCE='https://your_cool_instan.ce' bundle exec ruby app.rb
```


## Time input specifications

As of right now the bot is only able to parse times that come in certain formats:

- HH:MM:SS PM TZD (seconds field is optional, as are minutes. AM/PM is needed if specifiying 12 hour time)
- N seconds (or days/hours/weeks/minutes)

To make the status to the bot feel more like natural language you can also supply something like:

- in N seconds
- at HH:MM TZD

it will still parse out to the correct time

## TODO

- the ability to save the time into a database for restoring later (in case bot goes down)
- way to cancel reminders that you've scheduled

