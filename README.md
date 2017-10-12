Twitch adapter for Hubot
========================

[Hubot](https://hubot.github.com) is a chat bot by GitHub, modelled after their Campfire bot.
[Twitch](http://twitch.tv) is the world's leading video platform and community for gamers.
This adapter allows your Hubot to join channels on Twitch.

## Getting started

You will need a Twitch account to start, which you can [sign up for free](http://www.twitch.tv/signup).

Next, you will need to create an account for your Hubot.

Hubot defaults to using its shell, so to use Twitch instead, you can run hubot with ```-a twitch-adapter```:

```
% bin/hubot -a twitch-adapter
```

If you are deploying to Heroku or using foreman, you need to make sure the hubot is called with ```-a twitch-adapter``` in the Procfile:

```
web: bin/hubot -a twitch-adapter -n Hubot
```

## Configuring

The adapter requires the following environment variables.

- ```HUBOT_TWITCH_USERNAME```
- ```HUBOT_TWITCH_PASSWORD```
- ```HUBOT_TWITCH_CHANNELS```

You can use the [Twitch Chat OAuth Password Generator](http://twitchapps.com/tmi/) to generate a password for your Hubot.

### Configuring the variables on Heroku

```
% heroku config:set HUBOT_TWITCH_USERNAME="myusername"
% heroku config:set HUBOT_TWITCH_PASSWORD="oauth:mypassword"
% heroku config:set HUBOT_TWITCH_CHANNELS="#mychannel"
```

### Configuring the variables on UNIX

```
% export HUBOT_TWITCH_USERNAME="myusername"
% export HUBOT_TWITCH_PASSWORD="oauth:mypassword"
% export HUBOT_TWITCH_CHANNELS="#mychannel"
```

### Configuring the variables on Windows

Using PowerShell:

```
setx HUBOT_TWITCH_USERNAME="myusername" /m
setx HUBOT_TWITCH_PASSWORD="oauth:mypassword" /m
setx HUBOT_TWITCH_CHANNELS="#mychannel" /m
```

### Additional configuration

The adapter also supports the following environmental variables:

- ```HUBOT_TWITCH_CLIENT_ID```
- ```HUBOT_TWITCH_CLIENT_SECRET```
- ```HUBOT_TWITCH_REDIRECT_URI```
- ```HUBOT_TWITCH_OWNERS```
- ```HUBOT_TWITCH_DEBUG```
- ```HUBOT_TWITCH_DELAY```
