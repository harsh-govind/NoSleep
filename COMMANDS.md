# NoSleep: useful commands

Run these in Terminal.

## Stop the password prompt (one-time setup)
Lets only "turn sleep off / on" run without a password. Everything else still asks.

```sh
echo "$(whoami) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1" | sudo tee /etc/sudoers.d/nosleep >/dev/null && sudo chmod 440 /etc/sudoers.d/nosleep && sudo visudo -c
```
It worked if the last line ends in `parsed OK`.

## Undo the password setup
NoSleep goes back to asking for your password each time.

```sh
sudo rm /etc/sudoers.d/nosleep
```

## Check whether sleep is off
Shows `SleepDisabled 1` when NoSleep is ON, `0` (or nothing) when OFF.

```sh
pmset -g | grep SleepDisabled
```

## Turn sleep off / on without the app
```sh
sudo pmset -a disablesleep 1   # never sleep (lid closed too)
sudo pmset -a disablesleep 0   # normal sleep
```

## Build and install the app
```sh
./build.sh
pkill -x NoSleep; rm -rf /Applications/NoSleep.app
cp -R NoSleep.app /Applications/ && open /Applications/NoSleep.app
```

## Test that the admin password box works
```sh
osascript -e 'do shell script "pmset -g" with administrator privileges'
```

## See what NoSleep has been doing
Logs every switch, and every time it had to turn the setting back on because something reset it.

```sh
cat ~/Library/Logs/NoSleep.log
```
