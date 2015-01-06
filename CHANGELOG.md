OpenStudio::Workflow Change Log
==================================

Version 0.0.5 (Unreleased)
-------------
* Tests for programmatically creating the analysis.json files from the OpenStudio-analysis-gem
* Upgrade to EnergyPlus 8.2. Right now the run energyplus and run runmanager job hard code these paths.

Version 0.0.4
-------------
* Include rubyXL gem for reading/writing MS Excel files
* Remove invalid characters from OpenStudio Measure Attributes. /[|!@#\$%^&\*\(\)\{\}\\\[\]|;:'",<.>\/?\+=]+/
* Fix objective functions to read from any of the results hash, not just the standard report legacy
* Add time logger and reporting measure

Version 0.0.3
--------------
* Allow measures to set weather file in a measure and have it update what EnergyPlus uses for the weather file.
* OpenStudio::Workflow.run_energyplus method added to just run energyplus.
* Remove AASM (act as state machine) and replace with simple tracking of the state. Interface is the same except there is now no need to pass in the States.
* Catch EnergyPlus errors (non-zero exits), Fatal Errors in eplusout.err, and invalid weather files.
* Force UTF-8 version upon reading the eplusout.err file

Version 0.0.2
--------------

* Support reporting measures
* Reduce logging messages
* Keep IDF files
* Remove mtr and eso files after simulation completes
* If measure changes weather file, then use the new weather file with the analysis.json weather path

Version 0.0.1
--------------

* Initial release with basic workflow implemented to support running OpenStudio measure-based workflows
