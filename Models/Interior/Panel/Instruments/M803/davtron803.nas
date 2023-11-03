###############################################################################
##
## Davtron 803
##
##  Original from Nasal for DR400-dauphin by dany93;
##                    Clément de l'Hamaide - PAF Team - http://equipe-flightgear.forumactif.com
##  Heavily modified in 2017 for c182s by Benedikt Hallinger
##  Adapted in 2020 for DA40 by Benedikt Wolf
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Property and Path Setup
var volt_prop = nil;
if( getprop("/options/g1000") ){
	volt_prop = props.globals.getNode("/systems/electrical/outputs/av-cdu-fan", 1);
} else {
	volt_prop = props.globals.getNode("/systems/electrical/outputs/fan-oat", 1);
}
var davtron803	=	props.globals.getNode("/instrumentation/davtron803", 1);
var top_mode	=	davtron803.initNode("top-mode", "E", "STRING");
var bot_mode	=	davtron803.initNode("bot-mode", "UT", "STRING");
var path = "Models/Interior/Panel/Instruments/M803/";

############################
# Canvas implementation
############################
#print("Davtron 803 init: canvas");
var davtron_lcd_test_top    = "88.8E";
var davtron_lcd_test_bottom = "88:88";
var my_canvas = canvas.new({
  "name": "M803",   # The name is optional but allow for easier identification
  "size": [512, 512], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [512, 512],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 1       # Enable mipmapping (optional)
});

# add the canvas to replace basic texture of models lcd element
my_canvas.addPlacement({"node": "M803.display"});
#my_canvas.setColorBackground(0, 1, 0, .5);

# create groups holding some stuff
var bggroup  = my_canvas.createGroup();
var lcdgroup = my_canvas.createGroup();

# load davtron png image as background
bggroup.createChild("image")
        .setFile(path~"m803.png")
        .setSize(512, 512)
        .setTranslation(0, 0);      

# Create text element for upper line
var lcdfont = "DSEG/DSEG7/Classic/DSEG7Classic-Bold.ttf";
#var lcdfont = "DSEG/DSEG7/Classic-MINI/DSEG7ClassicMini-Bold.ttf";
var lcd_line_top = lcdgroup.createChild("text", "davtron.top.lcd.text_canvas")
                .setTranslation(125, 170)    # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont(lcdfont)            # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(80, 1.0)       # Set fontsize and optionally character aspect ratio
                .setColor(0,0,0)             # Text color
                .setText(davtron_lcd_test_top);

# draw the horizontal divider bar
var lcd_divider = lcdgroup.createChild("path", "davtron.top.lcd.divider_canvas")
        .setStrokeLineWidth(4).set("stroke", "rgba(0,0,0,1)")
        .moveTo(55, 224)
        .horizTo(900);

# Create text element for lower line
var lcd_line_bot = lcdgroup.createChild("text", "davtron.bot.lcd.text_canvas")
                .setTranslation(180, 280)    # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont(lcdfont)            # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(80, 1.0)       # Set fontsize and optionally character aspect ratio
                .setColor(0,0,0)             # Text color
                .setText(davtron_lcd_test_bottom);

# Create text elements for mode selection
var lcd_modes1 = lcdgroup.createChild("text", "davtron.bot.lcd.modes1_canvas")
                .setTranslation(65, 250)    # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("LiberationFonts/LiberationSans-Bold.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(40, 1.0)       # Set fontsize and optionally character aspect ratio
                .setColor(0,0,0)             # Text color
                .setText("UT LT");
var lcd_modes2 = lcdgroup.createChild("text", "davtron.bot.lcd.modes2_canvas")
                .setTranslation(65, 300)    # The origin is in the top left corner
                .setAlignment("left-center") # All values from osgText are supported (see $FG_ROOT/Docs/README.osgtext)
                .setFont("LiberationFonts/LiberationSans-Bold.ttf") # Fonts are loaded either from $AIRCRAFT_DIR/Fonts or $FG_ROOT/Fonts
                .setFontSize(40, 1.0)       # Set fontsize and optionally character aspect ratio
                .setColor(0,0,0)             # Text color
                .setText("FT ET")
                .setScale(1, 1.02);

# Underlining of selected item
var lcd_modesel = [
    lcdgroup.createChild("path", "davtron.bot.lcd.modesel_ut_canvas")
        .setStrokeLineWidth(4).set("stroke", "rgba(0,0,0,1)")
        .moveTo(65, 273)
        .horizTo(118),
    lcdgroup.createChild("path", "davtron.bot.lcd.modesel_lt_canvas")
        .setStrokeLineWidth(4).set("stroke", "rgba(0,0,0,1)")
        .moveTo(130, 273)
        .horizTo(180),
    lcdgroup.createChild("path", "davtron.bot.lcd.modesel_ft_canvas")
        .setStrokeLineWidth(4).set("stroke", "rgba(0,0,0,1)")
        .moveTo(65, 323)
        .horizTo(118),
    lcdgroup.createChild("path", "davtron.bot.lcd.modesel_et_canvas")
        .setStrokeLineWidth(4).set("stroke", "rgba(0,0,0,1)")
        .moveTo(128, 323)
        .horizTo(180)
];

# Shut dispaly off
var davtron_off = func() {
    lcd_line_top.hide();
    lcd_divider.hide();
    lcd_line_bot.hide();
    lcd_modes1.hide();
    lcd_modes2.hide();
    lcd_modesel[0].hide();
    lcd_modesel[1].hide();
    lcd_modesel[2].hide();
    lcd_modesel[3].hide();
};

# Turn display on
var davtron_on = func() {
    lcd_line_top.setText(davtron_lcd_test_top);
    lcd_line_bot.setText(davtron_lcd_test_bottom);
    lcd_line_top.show();
    lcd_divider.show();
    lcd_line_bot.show();
    lcd_modes1.show();
    lcd_modes2.show();
    lcd_modesel[0].show();
    lcd_modesel[1].show();
    lcd_modesel[2].show();
    lcd_modesel[3].show();
};

# Update the state of the selected top mode
var davtron_updateTopMode = func(){
    var value = davtron_lcd_test_top;
    var mode = top_mode.getValue();
    if        (mode == "E") {
        value = sprintf("%5.1fE", volt_prop.getDoubleValue());
    } else if (mode == "F") {
        value = sprintf("%5.1fF", getprop("/environment/temperature-degf"));
    } else if (mode == "C") {
        value = sprintf("%5.1fC", getprop("/environment/temperature-degc"));
    } else {
        # should not happen. Check XML config
    }
    lcd_line_top.setText(value);
    #print("Davtron 803: davtron_updateTopMode()");
};

# Update the state of the selected bottom mode
var davtron_updateBottomMode = func(){
    var value = davtron_lcd_test_bottom;
    var mode = bot_mode.getValue();
    var mi   = -1;  # index of selected mode indicator
    if        (mode == "UT") {
        value = getprop("/instrumentation/clock/indicated-short-string");
        mi = 0;
    } else if (mode == "LT") {
        value = getprop("/instrumentation/clock/local-short-string");
        mi = 1;
    } else if (mode == "FT") {
        value = getprop("/instrumentation/davtron803/flight-time");
        mi = 2;
    } else if (mode == "ET") {
        value = getprop("/instrumentation/davtron803/elapsed-time");
        mi = 3;
    } else {
        # should not happen. Check XML config
    }
    lcd_line_bot.setText(value);
    
    # update selected mode indicator
    var svabl = getprop("/instrumentation/clock/serviceable");
    var volts = volt_prop.getDoubleValue();
    if (svabl and volts) {
        for (var i=0; i <= 3; i = i+1) {
            if (mi == i) {
                lcd_modesel[i].show();
            } else {
                lcd_modesel[i].hide();
            }
        }
    }
    
    #print("Davtron 803: davtron_updateBottomMode()");
};

# Calculate current state and update clock
var davtron_on_off = func() {
    # see if we have power and are serviceable
    var svabl = getprop("/instrumentation/clock/serviceable");
    var volts = volt_prop.getDoubleValue();
    
    if (svabl and volts) {
        if (lcd_line_top.getVisible() != 1) davtron_on();
            
    } else {
        # shut down
        davtron_off();
    }
};




##########################################
# Flight timer / Elapsed timer
# Note: Currently only counting upwards is supported; whilst the device also supports count down mode!
##########################################


# Floor function
var floor = func(v) v < 0.0 ? -int(-v) - 1 : int(v);

# Time format function: Format time of property from secs to HH:MM format
var timeFormat = func(timeProp){

  elapsedTime = getprop(timeProp);

  hrs = floor(elapsedTime/3600);
  min = floor(elapsedTime/60);
  sec = elapsedTime;

  if (elapsedTime > 3599) {
    # Display HH:MM after 59:59 minute/ timer
    formattedTime = sprintf("%02d:%02d", hrs, min-(60*hrs));
  } else {
    formattedTime = sprintf("%02d:%02d", min, sec-(60*min));
  }
  
  return formattedTime;
}


# Called from Action binding when Control button is pressed
var controlButtonPressed = func {
    # Get the clock mode
    clock_mode = bot_mode.getValue();
    
    if (clock_mode == "FT") {
        # just note when the button was pressed
        controlBtnPressedAt = getprop("/sim/time/elapsed-sec"); 
    }
    
    if (clock_mode == "ET") {
        # handle ET timer: control cycles start->stop->reset
        if (!davtron_elapsed_time.running) {
            if (!elapsedTimeResetMarker) {
                davtron_elapsed_time.start();
            } else {
                davtron_elapsed_time.reset();
                elapsedTimeResetMarker = 0;
            }
        } else {
            davtron_elapsed_time.stop();
            elapsedTimeResetMarker = 1;
        }
    }

}

# Called from Action binding when Control button is released
var controlButtonReleased = func {
    clock_mode = bot_mode.getValue();
    
    if (clock_mode == "FT") {
        # reset FT only if pressed longer than 3 secs
        elapsedSimTime = getprop("/sim/time/elapsed-sec");
        if (controlBtnPressedAt+3 <= elapsedSimTime) {
            davtron_flight_time.reset();
        }
        controlBtnPressedAt = 0;
    }
    
}


###########
# INIT
###########
#print("Davtron 803 init: state");

# init state
davtron_on_off();
controlBtnPressedAt = 0;
elapsedTimeResetMarker = 0;

#print("Davtron 803 init: timers");
# init timers (API details: http://api-docs.freeflightsim.org/fgdata/aircraft_8nas_source.html )
props.globals.initNode("/instrumentation/davtron803/flight-time-secs",  0, "INT");
props.globals.initNode("/instrumentation/davtron803/elapsed-time-secs", 0, "INT");
var davtron_flight_time  = aircraft.timer.new("/instrumentation/davtron803/flight-time-secs", 1, 0);
var davtron_elapsed_time = aircraft.timer.new("/instrumentation/davtron803/elapsed-time-secs", 1, 0);

# Activate the FT timer at startup of elec system
# and stop if no power registered (note, the ET timer seems to count on as seen in real life. FT timer behavior is not verified in this way and may be wrong)
setlistener(volt_prop, func(clocknode) {
    if (clocknode.getValue() > 1) {
        davtron_flight_time.start();
    } else {
        davtron_flight_time.stop();
    }
}, 1, 0);

#print("Davtron 803 init: update loop");
# Generate formatted output in separate properties
timeFormatUpdateLoop = maketimer(1, func(){
            setprop("/instrumentation/davtron803/flight-time", timeFormat("/instrumentation/davtron803/flight-time-secs"));
            setprop("/instrumentation/davtron803/elapsed-time", timeFormat("/instrumentation/davtron803/elapsed-time-secs"));
            
            # Update the LCD values
            davtron_updateTopMode();
            davtron_updateBottomMode();
        });
timeFormatUpdateLoop.start();

#print("Davtron 803 init: listeners");
# Listen to changes in power and serviceable to enable/disable the clock
setlistener("/instrumentation/clock/serviceable", davtron_on_off, 1, 0);
setlistener(volt_prop, davtron_on_off, 1, 0);

# Listen to changes in config so davtron responds timely
setlistener(top_mode, davtron_updateTopMode, 1, 0);
setlistener(bot_mode, davtron_updateBottomMode, 1, 0);


print("Davtron 803 initialized");
