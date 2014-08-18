#Slic3r tool reordering post processing script
#Daniel Fitzgerald 2013

#Slic3r uses a nearest neighbors search to optimize the order of tools ussed in each layer based on the current tool, offsets between tools, and the locations of the "islands" of the layer
#we don't care about any of that and want our tools used in the order of their numbers
#this script finds code chunks associated with each tool used on a layer and rearranges them in the order of the tool numbers

#note that it is best to save the lift before a tool change with the chunk for that tool.

#NOTE: when tool changing on layer change, Slic3r does Layer change THEN Tool change in the form:
	#...fill...
	#move to next layer (n) and lift
	#reset extrusion distance
	#POSTPROCESS: LAYER CHANGE HERE
	#POSTPROCESS: TOOL CHANGE FROM a TO b
	#Tb;
	#reset extrusion distance
	#move to first perimeter point
	#restore layer Z
	#compensate retraction
	#...perimeter...

#!/usr/bin/perl -i
use strict;
use warnings;
	
my $toolWasFromLastLayer;#flag indicating that the first tool on this layer was the last tool on the previous layer, meaning it did not originally need a tool change command (but will now!)
my @sortOrder;		 #order of tools to use on each layer
my %toolChunks=();	 #hash of string of chunks of code associated with each tool
my $curLayer=-1;	 #current layer (first layer is 1)
my $pastEndOFLastLayer=0;#flag set when end of relivant file is reached
my $pastFirstDisableFan=0;#flag for keeping track of how many M107 disable fans we've seen (last one indicates end of relivant G Code)
my $beforeFirstLayer=1;	 #flag set before relivant part of file is reached
my $curTool=0;		 #current tool index (zero based)
my $prevTool=0;

$^I = 'TOOLREORDERER.bak';	#save a backup file to appease Windows
while(<>){	#loop through lines of file
	
	#print everything past the end of the last layer as-is
	if ($pastEndOFLastLayer==1){
		print or die $!;
		next;
	}else{
		

		#detect tool changes
		if (/T(\d+) ; change extruder/ or /POSTPROCESS: TOOL CHANGE FROM (\d+) TO (\d+)/){		
			$prevTool=$curTool;
			$curTool = ((defined $2) ? $2 : $1);	#set the cur tool to the captured value from whichever statement was hit
			
			$toolWasFromLastLayer=-1;	#reset flag - if we're changing tools, then the new tool was definitly not carried over from last layer
			
			#we've definitly reached the start of relivant code if we're at a tool change
			if ($beforeFirstLayer==1){
				$beforeFirstLayer=0;
			}
		}
		
		#ignore everything before the first layer
		if ($beforeFirstLayer==1){
			print or die $!;
			next;
		}else{
			
			#find and skip the first M107 disable fan
			if ($pastFirstDisableFan=0 and /M107/){
				$pastFirstDisableFan=1;	#set flag
				print or die $!; 	#print this line
				next;			#go on to rest of code
			}else{
			
				#detect code right after end of last layer
				if (/POSTPROCESS: END G CODE/ or (/M107/ and $pastFirstDisableFan)){
					$pastEndOFLastLayer=1;	#set flag
					&printLastChunk;
					print or die $!;
					next;
				}
				
				#--------------------------- process rest of code ---------------------------
				 				
				#detect start of a new layer
				if (/; move to next layer \((\d+)\)/ && ($1 != $curLayer)){
					$curLayer=$1;	#record current layer
					
					&printAllChunks;	#print all tool chunks
					undef %{toolChunks};	#%{toolChunks}=();	#clear all tool chunks
					print or die $!; 	#print this line as-is
					
					$toolWasFromLastLayer=1;#set flag - assume the current tool was going to be used as the first tool ont the next layer
					
					next;			#go on to rest of code 
				}else{	#for all other lines
					
					#if this flag is still set, it means we just switched layers but did not emmediatly have a tool change.
					#whatever tool we're on now, it was carried over from the last layer and we'll need to add a tool change to the start of its code
					if ($toolWasFromLastLayer>=0){	
						$toolChunks{"$curTool"}.="WhenPrintingAddToolChangeHere";	#note that this chunk will require a tool change to be added			
						$toolWasFromLastLayer=-1; 	#reset flag.
					}
					
					#add the rest of the line to the chunk
					$toolChunks{"$curTool"}.=$_;	#add this line to the current, followed by a tool change
				}
			}
		}
			
		
	}
}

sub printLastChunk{
	&printAllChunks;	#print the tool chunks in order for the last layer
 
}

#print the hash of tool chunks sorted by increasing tool numbers
my $prevKey=0;	#save the key (tool number) before the current
sub printAllChunks{
	@sortOrder = sort keys %toolChunks;	#extract keys (tool numbers used on this layer), sort, and save to any array
		
	#COMMENT to use asxending tool order	
	#@sortOrder=reverse(@sortOrder);	
			
	print "\n;\tPRINTING TOOL CHUNKS FOR LAYER $curLayer IN ORDER OF\t@sortOrder...\n";
			
	#loop through keys in order and print corresponding tool chunk
	foreach my $key (@sortOrder){
		
		print "\n;\tCHUNK $key\n";
		my $chunk=$toolChunks{$key};	#extract each chunk from the hash
		
		#if the chunk requires a tool change at the start, add one
		if(($chunk =~ s/WhenPrintingAddToolChangeHere//) and ($key != $prevKey)){	
			print ";\tADDING EXTRA TOOL CHANGE FROM REARANGED TOOL ORDER...\n";
			print "POSTPROCESS: TOOL CHANGE FROM $prevKey TO $key\n";
			print "T$key ; change extruder\n";
			#print "G1 F30000\n";	#hack
		}

		print $chunk;
		
		print ";\tEND CHUNK $key\n";
		
		$prevKey=$key;	#record the current key (tool) as the last one used
	}
}


