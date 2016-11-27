# AutoSSH.app

### Install

- run setup.sh
- Set your browser to open the autossh.autossh files with the AutoSSH.app

#### iTerm Setup

Two options:

1) Import the profile template provided (iterm2_profile.json)

2) Create an iTerm2 profile and open it to edit it
	- in the badge field, paste the line below and save
	    \(user.BADGE)
	- Under "Advanced" -> "triggers" add a trigger using the info below
		- Regex: Connection to pacha\.cpanel\.net closed\.
		- Action: Run Coprocess
		- Parameters: /usr/bin/env python /Applications/AutoSSH.app/clear_session.py
		- Instant: enabled

### Usage

The application will open the autossh.autossh file it was passed and run the Autossh4.pl script in the active session of iTerm. It will then set a badge to the ticket number.

Once you disconnect, the terminal session will automatically be reset and the badge will be cleared.

Make sure that the session you want to use in iTerm is active before clicking the ssh button in the ticket system. 
