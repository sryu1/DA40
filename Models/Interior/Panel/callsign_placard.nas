###############################################################################
##
##  Dornier 228 Callsign Placard
##
##  Original: Davtron 803
##  Original from Nasal for DR400-dauphin by dany93;
##                    Clément de l'Hamaide - PAF Team - http://equipe-flightgear.forumactif.com
##  Heavily modified in 2017 for c182s by Benedikt Hallinger
##  Modified in 2020 for M811 by Benedikt Wolf
##  Modified in 2020 for Callsign Placard by Benedikt Wolf
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Properties
var callsign = props.globals.getNode("/sim/model/livery/callsign", 1);
if( callsign.getValue() == nil ){
	callsign.setValue("N/A");
}

############################
# Canvas implementation
############################

var my_canvas = canvas.new({
	"name": "Callsign Placard",   # The name is optional but allow for easier identification
	"size": [512, 512], # Size of the underlying texture (should be a power of 2, required) [Resolution]
	"view": [512, 512],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
	# which will be stretched the size of the texture, required)
	"mipmapping": 1       # Enable mipmapping (optional)
});

# add the canvas to replace basic texture of models lcd element
my_canvas.addPlacement({"node": "placard.callsign"});
#my_canvas.setColorBackground(0, 1, 0, .5);

# create groups holding some stuff
var bggroup  = my_canvas.createGroup();
var textgroup = my_canvas.createGroup();

bggroup.createChild("image")
		.setFile("Models/Cockpit/Glareshield/glareshield.png")
		.setSize(512, 512)
		.setTranslation(0, 0);      

var callsign_line = textgroup.createChild("text", "callsign.placard.text")
		.setTranslation(300, 53)   		 		# The origin is in the top left corner
		.setAlignment("center-center") 				# All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
		.setFont("LiberationFonts/LiberationSans-Bold.ttf")	# Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
		.setFontSize(60, 1.0)					# Set fontsize and optionally character aspect ratio
		.setColor(0.0,0.0,0.0)					# Text color
		.setText(callsign.getValue());

var update_callsign = func () {
	callsign_line.setText( callsign.getValue() );
}

setlistener(callsign, update_callsign);
