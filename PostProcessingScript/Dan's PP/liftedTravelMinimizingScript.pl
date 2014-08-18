#	liftedTravelMinimizingScript.pl
#	Daniel Fitzgerald
#	06/13/2014
#	Description:
#This Slic3r post processig scripts operates on g-code exported by slic3r version 1.01 using the "Megacaster settings from TB"
#It eleiminates extraniouse lifted travel moves produced by Slic3r, characterized by two or more sequential "; move to first fill point" commands.

#!/usr/bin/perl -i
use strict;
use warnings;

my $justMovedToFirstFillPoint=0; 	#flag set when the current g-code line is "move to first perimeter|fill point"
my $lastFillPointCommand=";";	#the rest of the last coordinates from the "first perimeter|fill point"


$^I = 'LiftedTravelMinimizingScript.bak';	#save a backup file to appease Windows
while(<>){	#loop through lines of file
	#found a lifted travel command
	if (/; move to first fill|perimeter point$/){
		print ";".$_;
		$lastFillPointCommand = $`;	#record the actual command in case it is the last so we replace it later
		$justMovedToFirstFillPoint=1;	#mark flag that we are in the middle of our lifted travel
		next;
		
	#found anything other than a lifted travel command
	}else{
		if ($justMovedToFirstFillPoint==1){	#if the previouse line was a lifted travel (the last in a potential series of extranious lifted travels
			print $lastFillPointCommand."\t; move to first (last) fill point\n";
			$justMovedToFirstFillPoint=0;		#reset flag
		}	
	}
	
	#DONE with in line edititng! Print whatever's left of the current line!
	print or die $!;	#print the line back or, if that fails, print the error message	  $!what just went wrong bang?
}

