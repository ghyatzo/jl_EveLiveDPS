# Disclaimer
THE CURRENT STABILITY OF THIS TOOL CAN BE DESCRIBED AS "IT WORKS ON MY MACHINE" AND IT IS STILL IN THE WORKS, treat it as such.

# Description
Application to live record combat log data and present the user with useful statistics about the fight. Written in Julia with Dear Imgui as graphical interface.

It should be crossplatform, but currently only tested on MacOs.

![Demo Picture](img.jpg?raw=true "Demo picture")

Should ever this tool make you cry out of joy or stir in you feelings you didn't know you had, consider making an ISK donation to Bin Bucket.

## What it currently does:
### Tracking
- Damage In/Out
- Logistic (aggregated) In/Out
- Cap Transfer
	+ In: Cap Received + Personal Nos Drain
	+ Out: Cap Transfered
- Cap Damage:
	+ In: Enemy Neuting + Enemy Nos Drainage
	+ Out: Neuting + Personal Nos Drain
- Mining (Amount, no m3 yet)

### Highly Customizable Plotting & High Accuracy DPS estimation
You can change which information to show and play with the graph configuration, such as: the size of the moving window (default to 60 seconds) or how smooth you wish the time series to be (less smooth: more responsive but noisier. More smooth: a bit less responsive but gives more gawkable informations at a glance).
You can access the configuration window from menu->Show Config Window
Two visual indicators bar that can be hidden, to manually set some kind of threshold you need to see at a glance (i.e. How much tank your ship can take, and how much when heated.)

This tool tries to smooth out as best it can to give you the closest estimate to the theoretical dps you are doing, while still considering all other variables. No more dancing around the true average dps.

P.S.: you can double-right click on any graph, to show a contextual menu with some more options.

#### Extra info
- Top 5 sources for total damage, who did the most damage so far (other metrics supported too)
- Top 5 sources for highest alpha damage, who hits the hardest (other metrics supported too)
- Damage application distribution graph (hits, penetrates, etc...)
- Others as soon as I come up with other barely useful informations to show...

### Concurrent Multicharacter Support
Automatically detects all recent characters you logged in with and new ones. You can then start and stop the logging for each character indipendently.

The parsing can be active only for one character at a time, but the log information is gathered in the background for all loaded characters to be processed upon activation.

Logged out, and logged back in? no problem, the program knows this and automatically switches to the most recent log file.

### Custom Overview Support
Reads the custom overview setting file associated with a capsuleer and updates the parser to correctly parse all information form the combat log messages.


## TODO
- Handling of mining volumes instead of mining amounts (WIP)
- Support other locales other then english
- update to newer versions of DearImgui that support docking and multiple viewports. (upstream(ish) issue)

# Usage
Once started, the application should work automatically.
If it fails to detect the log folder it will refuse to work until one is provided. (you will be asked to select a folder.)

The app will scan the log folder, loading up the most recent log files for all capsuleers that recently logged in (not older than a day).

On the top bar, a list of the detected capsuleers names is shown. At first no character will be active, as well as the parser.
To activate a character and start reading from its log file, simply click on its name, to start parsing and start showing data on the graph window, click the `Start Parsing` button (if there is no active character, nothing will happen).

Characters with a green background are `active`, only one character at a time can be active.

Characters with a yellow background are `ready`: They have an associated log and overview setting file, and can be activated when desired.

Characters with a red background are `incomplete`: A log file for them was found but they do not have an associated overview setting file. If an `incomplete` character is activated, you will be shown a warning, asking to select an overview file (more below), you can disregard this warning, but by doing you accept the parsing will be unreliable and incomplete.
(If you really are playing with the default overview settings, you can simply export the default settings as if it were a custom one to get rid of the warning, more below.)

## Custom Overviews
Instead of manually selecting the overview file each time you can help the application automatically select it for you.

The application tries to automatically detect the default overview folder (where EVE exports your overview settings).

Moreover, it will try to automatically detect an overview to associate to a newly loaded capsuleer. Since overview settings don't have any information regarding the capsuleer that exported it, the app will scan the overview folder looking for a `.yaml` file starting with the pattern `jeld_<capsuleer name>` (i.e `jeld_luke skywalker-myoverview.yaml`).
All files after the first one, matching the pattern above, are ignored.

If you keep your files in a different folder, no fret, you can still manually change the overview.

# Running from source
The end goal is to build a single working binary application, click and forget. At the moment, due to some upstream julia compatibility issues and minor bugs, the process of creating an executable is not working (it will be).

To run this tool you need a working version of julia for your machine (check out `juliaup`)
- clone the repo in a folder
- cd into that folder
- type into a terminal (in that folder) `julia -q --project src/JlEVELiveDPS.jl`

The first time around it will probably take a long time to start, since it will need to download all the dependencies and compile them. If you want a more interactive experience, 
- start a julia REPL in the terminal by typing `julia`
- go into `package mode` by pressing `]`, the prompt should turn blue
- type `activate .` (not a typo, its `activate (dot)`), you should see `(JlEVELiveDPS)` at the start of the prompt
- followed by `instantiate`
Julia will then download all needed dependencies, precompile them and make them available to the application when starting.
