# RemindMeBot

This is a complete reworking of the original RemindMe bot I made using python (hosted over [here](https://botsin.space/@RemindMe))

I feel like this bot will be better able to parse messages and scheduling replies

Feel free to help out if you want!


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
