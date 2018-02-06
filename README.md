# RemindMeBot

This is a complete reworking of the original RemindMe bot I made using python (hosted over [here](https://botsin.space/@RemindMe))

I feel like this bot will be better able to parse messages and scheduling replies

Feel free to contribute if you want!

# Running personal version

You'll need to set your database settings in `db.yml`. An example is provided in `db.example.yml`.

```bash
cp db.example.yml db.yml
$EDITOR db.yml
```

When running the bot you need to specify an instance, a mastodon access token, and the username of the bot on the command line

Something like:
```bash
BEARER='your_access_token_here' ACCT='BotNameHere' INSTANCE='https://your_cool_instan.ce' bundle exec ruby app.rb
```


## Features

- scheduling reminders (see Time Input Specifications below)
- canceling reminders that have yet to go off
- saving/restoring to a (MySQL/MariaDB) database


## Time input specifications

As of right now the bot is only able to parse times that come in certain formats:

- HH:MM:SS PM TZD (seconds field is optional, as are minutes. AM/PM is needed if specifiying 12 hour time)
- N seconds (or days/hours/weeks/minutes)

To make the status to the bot feel more like natural language you can also supply something like:

- in N seconds
- at HH:MM TZD

it will still parse out to the correct time

## TODO

- command to repeat a reminder

