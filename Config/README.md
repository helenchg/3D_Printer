# **Slic3r Config Documentation**
**Author:** Elena Chong, Michael Perrone

**Date:** 7/21/2014

**This is the documentation for the different Slic3r configurations.** 
**Doubts/questions should be directed to the respective person who prepared the Slicer config.**                         

# Printing with Prusa i3 
-------------------------
### Config: ConductivityTracesConfig
**Prepared by:** Elena Chong 

**Detail:** Modified from Dan Fitzgerald's ArduinoCircuit Config

**Description:** Used for printing circuit on plastic.
We can print the plastic and the ink as separate gcode files. This allows us to print one thing completely, home the printer, load the ink gcode, then do dry runs with the silver extruder to make sure the position of the two extruders are calibrated properly before actually printing with the silver ink. You will need to separate the gcode for the plastic and the silver ink. All moves are in absolute coordinates, so if you home the printer in between prints it will go to where it left off
	
Steps:

1. Open Slic3r and load config
2. File - Combine multi-material STL files...
3. Open the plastic .stl, then the ink stl 
4. If there is no more file, click cancel. Save resulting file as .amf
5. open .amf file 
6. Export as .gcode
7.	- Nonembedded: open .gcode file, open search (CRTL + F) for T1 (ink extruder) - this should be at the end Cut from line T1 to before the line before T0. 
Open a new file and paste the ink trace code there, save as .gcode

	- Embedded: You will either have to separate the amf gcode into three separate gcode files (bottom, ink, top) or you can add a pause before printing the ink by copy and paste the following lines into the place before T1 (change of extruder)
		
			G400 #Finish all current moves
			G91 # Relative coordinates
			G1 X20 Z30; #Lift extruder to allow space to work
			G4 P60000 # Pause for a 60 seconds (add more time or hit pause button)
			G1 X-20 Z-30; # Go back to initial position to resume printing
...T1 (ink) CODE
	8. Open Pronterface - Open .gcode file and print



### Config: MultilayerConfig
**Prepared by:** Elena Chong

**Description:** Used for printing multilayer (Z axis) embedded ink traces. If you are just printing plastic and traces (No adding components) you don't need to edit the gcode. You can go straight to printing.

# Printing with CoreXY Printer
-------------------------------

### Config: lewis_corexy_1_MultiExtruder
**Prepared by:** Elena Chong

**Detail:** Modified from Steve Kelly's lewis_corexy_1 single extrusion config and Dan's postprocessingscript
**Description:**	Calibrated for dual extrusion (Plastic and Ink) to print on the CoreXY Printer. Just changed "Print center" and " Extruder offset"
### NOTE: Steps taken to adapt postprocessingscript for the corexy printer:
* First, edit Dan's PrusaCircuitConverterScript.pl to use M42 P6 instead of M42 P32, then add the file directory into Slic3r - Print Settings - Output options
* Second, add these into Slic3r - Printer Settings - Custom G-code

Start G-code:
		
			G28 ; home all axis
			G1 Z5 F5000 ; lift nozzle
			;CIRCUIT_POST_PROCESSOR: RETRACT_LENGTH = ,[retract_length]
			;CIRCUIT_POST_PROCESSOR: RETRACT_LENGTH_TOOLCHANGE = ,[retract_length_toolchange]
			;CIRCUIT_POST_PROCESSOR: RETRACT_LIFT = ,[retract_lift]
			;CIRCUIT_POST_PROCESSOR: RETRACT_SPEED = ,[retract_speed]
			;CIRCUIT_POST_PROCESSOR: RETRACT_RESTART_EXTRA = ,[retract_restart_extra]
			;CIRCUIT_POST_PROCESSOR: RETRACT_RESTART_EXTRA_TOOLCHANGE = ,[retract_restart_extra_toolchange]
			;CIRCUIT_POST_PROCESSOR: BEGIN G CODE
			
End G-code:
		
			M00
			M42 P32 S0
			G91
			Z10
			G90
			M104 S0 ; turn off temperature
			G28 X0  ; home X axis
			M84     ; disable motors
			;END G CODE
			
* Last, Make sure to enable Wipe while retracting by going into Printer Settings - Extruder 1 - Rectraction.
		
	

	
	
	
	
