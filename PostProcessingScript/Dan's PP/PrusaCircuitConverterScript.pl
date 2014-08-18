#	Arduino Test Script 1
#	Daniel Fitzgerald
#	06/13/2014
#	Description:
#This Slic3r post processig scripts operates on g-code exported by slic3r version 1.01 using the "Megacaster settings from TB"
#It converts the second extruder to print conductive ink using direct-write technology instead of FDM (Fused-deposition-modeling)
#There are several modifications:
#	-Add pressure box commands to turn nozzle pressure on and off appropriatly
#	-Override feedrate commands so the nozzle extrudes traces with a constant speed
#	-Eliminate normal reprap extruder commands during direct-write extrusion
#	-


#NOTES on SLic3r Parameter hijacking
#	-Printer Settings -> Extruder <n>1> -> retraction -> Length = pressure for nozzle (in psi)
#	-Printer Settings -> Extruder <n>1> -> retraction -> Speed = feedrate for nozzle (in psi)
#	-Printer Settings -> Extruder <n>1> -> retraction -> Extra length on restart = dell time for nozzle on starting a trace(in ms)

#notes on tuning: 
#	use Slic3r setting for nozzle offsets, nozzle diameters, temperatures, etc.
#	no pressure control yet

#!/usr/bin/perl -i
use strict;
use warnings;

#printer state variables
my $pressureOn=0;		#if the presure is currently on
my $curExtrudingInk = 0;	#is the printer thinks it is currently extruding ink on this layer
my $curToolIndex=0;		#currently lifted above the layer for traveling
my $curLayerHeight = 0;
my $curLayerNumber = -1;
my $inGCodeBody = 0;		#have we reached the main body of the g code (or still in header comments)
my $curZHeight =0;		#current Z height

#G Code commands to insert
my $strPressureOn = "M400\nM42 P32 S255 ; Pressure on\n";
my $strPressureOff = "M400\nM42 P32 S0 ; Pressure off\n";
my $strPauseCode = "M400\nM25 ; Pause\nM601 ; record current position\n";
my $strResumePause = "M602\nM24 unpause\n";
my $pauseHookDwellTime = 60000;
my $strEndFDMGCode = "\n\nEND FDM G CODE\nM400\nM42 P32 S0\nG91\nG1 Z5 F6000\nG90\nSEPARATE HERE\n\n";#";END FDM G CODE\nM400\nM42 P32 S0\nG91\nG1 Z5 F6000\nG90\nG1 X5\nM400\nG4 P".$pauseHookDwellTime." ; Dwell to catch component insertion pause.\n\nSEPARATE HERE\n\n";

my $dwellTimeBeforeRetraction = 1;#200;	#ms
my $dwellTimeAfterRetractionCompensation = 1;#200; #ms

#hard coded
my $lastFFDtoolIndex = 1.2;	#index of the last ordered extruder that is FDM

#Extracted Slicer Parameters
my @retract_speeds;				#list of retraction speeds for extruders
my @retractLengthToolchange;			#list of retract lengths for tool changes of extruders
my @retractRestartExtra;			#list of retraction lenths added to retraciton compensation for each nozzle
my @retractRestartExtraToolchange;		#list of retraction lenths added to retraction compensation on tool changes for each nozzle

#FIXME
my $looking_for_next_moveToFirst = 0;

#offsets
#my $layerHeight=0.2;
#my $numlayersFromTop = 2;
#my $layerHeightOffset = -$numlayersFromTop*$layerHeight;			#hard coded for now

my $FFDretractSpeedMultiplier=60;
my $PNNozzleFeedrateDivider=10;

$^I = 'PrusaCircuitConverterScript.bak';	#save a backup file to appease Windows
while(<>){	#loop through lines of file
	
	#if the start of the body of the g code hasn't been reached yet
	if ($inGCodeBody==0){
		
		#search for a post-procesor directive (Custom G code lines inserted by slic3r config)
		if (/;CIRCUIT_POST_PROCESSOR: /){	#found a Custom Start G-Code command with Slicer parameters
			if (/BEGIN G CODE/){
				$inGCodeBody=1;
				print ";\tFOUND START OF G CODE\n";
			}elsif (/RETRACT_SPEED = (.*)/){	#Extract an array of extruder retraction speeds
				my $strRetractSpeedList=$1;	#get the string with comma-separated retraction speeds
				my $retractSpeed=0;		#currently extracted retraction speed
				my $count=0;			#loop index
				while ($strRetractSpeedList =~ /,(-?\d+\.?\d*)/g){	#loop through the list
					$retractSpeed=$1;				#extract the number
					$retractSpeed*=60;				#mm/s to mm/min
					push(@retract_speeds, $retractSpeed);		#push to list
					$count+=1;
				}
				local $"=', ';
				print ";\tFound $count retract speeds: @retract_speeds\n";
			}
		}#end ifCircuit_Post_Processor
		
		#print harmless beginning code anyway
		print or die $!;
	#start of G Code has already been found	
	}else{
		
		if (/G28 X0  ; home X axis/){
			print "G1 Z".($curZHeight+10)." ; final raise before X home\n";
			print;
			next;
		}

#		if (/END G CODE/){
#			$inGCodeBody=0;
#			print ";\tREACHED END OF G CODE\n";
#		}
		
		#record Z heights
		if (/Z(-?\d+.?\d*)/){
			$curZHeight = $1;
		}
	
		#find and record layer changes
		if (/move to next layer \((\d+)\)/){
			$curLayerNumber = $1;
			print "; move to next layer: ".$curLayerNumber." detected. Resetting Extrusion distance.\n";
			&resetExtrusionDist;
		}
	
#		#if we just changed tools, we want to hover over the point the next tool will start at and allow the user to pause to check nozzle alignment
#		if ($looking_for_next_moveToFirst ==1 and /^G1.*; move to first/){
#			$looking_for_next_moveToFirst=0;
#			print "M400\nG4 P".$pauseHookDwellTime." ; Dwell to catch nozzle alignment pause.\n";
#		}
	
		#SKIP EVERYTHING EXCEPT THE LAST LAYER (#7)
		#if ($curLayerNumber<0 or $curLayerNumber >=6){
	
			#don't set temp tof extruder 1
			next if (/M109.*T1/ or /M104.*T1/);
		
			#SUBTRACT Z OFFSET
#			if (/Z(-?\d+\.?\d*)/){
#				$_=$`." Z".$1.$';	#($1+$layerHeightOffset).$';
#			}
		
			#detect tool change as a line that starts with T<n> where <n> is any digit. Record the current tool for subsiquent lines.
			if (/^T(\d+)/) {
				$curToolIndex = $1;
				print;
				&resetExtrusionDist;
				
				if ($curToolIndex == 1){
					print $strEndFDMGCode;
					$looking_for_next_moveToFirst = 1;
					print "G1 Z".$curZHeight."; restore Z Travel Height before continuing print\n";
				}
				
				next;
			}
			
			#for all other lines, if the current tool is #1 (ink)
			if ($curToolIndex == 1){
				
				#skip ink perimeters
				#next if (/; skirt/)
				
				#skip reset extruder distance
				if (/G92/){
					print "; G92 - no reset extruder distance\n";	#print blank line (retain line numbers for easy comparison of before/after postscript code)
					next;
				}
										
				#if we are currently retracting (wiping or something) - deactivate extrusion
				if (/; retract$/ or /; retract for tool change$/){
					&turnPressureOff;					#turn pressure off if it isn't already
					if (/G1 F-?\d+\.?\d*.*E?-?\d+\.?\d*.*; retract/){	#skip flat-out retractions
						print ";commented retraction: ";				#comment the line.
					}
				}
			
				#detected a perimeter or fill (must activate extrusion)
				if (/; perimeter$|fill$/){
					&turnPressureOn;	#turn pressure on if it isn't already before printing this line as-is.
				}elsif (/; compensate retraction/){
					&turnPressureOn;	#turn pressure on if it isn't already before printing this line as-is.
					print ";".$_;
					next;
				}
				
				#get rid of all extruder commands for the second extruder.
				if (/E-?\d+\.?\d*/){
					$_=$`." ".$';	#concat the string preceeding the match with that following the match. Saves back in to default var.
				}
				
				#find all the "move to first perimeter/fill" commands and the first subsequent perimeter/fill command. Replace the feedrates for ink extrusion with the extracted ink feedrate.	
				if(/(.*)F\d+\.?\d*(.*)(fill|perimeter)$/){
					print $1." F".$retract_speeds[1]." ".$2.$3."; replaced feedrate - PrusaCircuitConverterScript\n";	#replace the feedrate with the feedrate (retraction speed) extracted from the header.
					next;
				}
				

			}
		
			#DONE with in line edititng! Print whatever's left of the current line!
			print or die $!;	#print the line back or, if that fails, print the error message	  $!what just went wrong bang?
		
		#for any other layer than the 7th
#		}else{
#			next;
#		}
	}#end GCode Body
}

sub resetExtrusionDist{
	print "G92 E0 ; reset extrusion distance - PrusaCircuitConverterScript\n";
}

#turn pressure nozzle on
sub turnPressureOn{
	if ($pressureOn==0){
		print $strPressureOn;
		print "G4 P".$dwellTimeAfterRetractionCompensation." ; dwell after retraction compensation\n";
		$pressureOn=1;
	}
}

#turn pressure nozzle off
sub turnPressureOff{
	if ($pressureOn==1){
		print "G4 P".$dwellTimeBeforeRetraction." ; dwell before retracting\n";
		print $strPressureOff;
		$pressureOn=0;
	}
}