# Daily Memories

This bash script obtains immich memories and joplin notes of this date in the past, combines them, and sends them as an email.
Works on my machine™.

## Assumptions

- Immich server container running on the same host as the script is being run from.
- Joplin data accessible through [rickonono3/joplin-terminal-data-api](https://hub.docker.com/r/rickonono3/joplin-terminal-data-api).
- Ability to send mail through the mail command, for example after setting up SMTP.
- Pandoc cli installed to convert md to html.

## Usage

- Clone this repository:

    ```bash
    git clone https://github.com/nelisss/immich_joplin_memories.git
    ```

- Copy the .env.template file and fill in your values:

    ```bash
    cp .env.template .env
    nvim/nano/... .env
    ```

- Make the script executable and run it:

    ```bash
    chmod +x immich_joplin_memories.sh
    ./immich_joplin_memories.sh
    ```

### Get daily memories using a systemd service

Install a systemd service and timer to run the script daily.

daily_memories.service (replace path with path to script): 

```bash
[Unit]
Description=Send daily memories mail

[Service]
Type=oneshot
ExecStart=/bin/bash "/path/to/daily_memories.sh"
```

daily_memories.timer (you can adjust the time to your liking): 

```bash
[Unit]
Description=Send daily memories mail

[Timer]
OnCalendar=*-*-* 07:00:00
Unit=daily_memories.service

[Install]
WantedBy=timers.target
```

Put both in /etc/systemd/system/ or /home/[user]/.config/systemd/user/, and run `systemctl enable --now daily_memories.timer`. Use --user flag if the service and timer are in ~/.config.

The same can be achieved using cron.

## Issues

- Very much untested. Works for me, probably not for you.
- Joplin filtering doesn't actually return entries from x years ago, but from x * 365 days ago. I don't think the search filters allow for filtering by a certain date across years.
- Haven't looked into what permissions are needed for Immich api key. For now, I use a key with full permissions.
