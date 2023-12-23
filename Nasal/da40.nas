#	Diamond DA40

#	Tyre Smoke
#============================ Tyre Smoke ===================================
 aircraft.tyresmoke_system.new(0, 1, 2);
 #============================ Rain ===================================
 aircraft.rain.init();
 # == making the timer ==
 var raintimer = maketimer(0,
     func(){
         aircraft.rain.update();
     }
 );
 # == fire it up ===
 raintimer.start();
 # end 

# Set transponder to 1200
setprop("/instrumentation/transponder/inputs/digit[3]", "1");
setprop("/instrumentation/transponder/inputs/digit[2]", "2");
setprop("/instrumentation/transponder/inputs/digit[1]", "0");
setprop("/instrumentation/transponder/inputs/digit[0]", "0");
setprop("/instrumentation/transponder/id-code", 1200);

#	FG1000 Panel Variant:

var nasal_dir = getprop("/sim/fg-root") ~ "/Aircraft/Instruments-3d/FG1000/Nasal/";
io.load_nasal(nasal_dir ~ 'FG1000.nas', "fg1000");
io.load_nasal(nasal_dir ~ 'Interfaces/GenericInterfaceController.nas', "fg1000");

var interfaceController = fg1000.GenericInterfaceController.getOrCreateInstance();

interfaceController.start();

var fg1000system = fg1000.FG1000.getOrCreateInstance();

# Create a PFD as device 1, MFD as device 2
fg1000system.addPFD(1);
fg1000system.addMFD(2);

# Display the devices
fg1000system.display(1);
fg1000system.display(2);
	
# Switch the FG1000 on/off depending on power.
setlistener("/controls/electric/avionic-master", func(n) {
	if (n.getValue() > 0) {
		fg1000system.show();
	} else {
		fg1000system.hide();
	}
}, 0, 0);

# Control the backlighting of the bezel based on the avionics light knob
setlistener("/controls/lighting/instrument-lights", func(n) {
	if (getprop("/systems/electrical/outputs/mfd") > 5.0) {
		setprop("/instrumentation/FG1000/Lightmap", n.getValue() );
	} else {
		setprop("/instrumentation/FG1000/Lightmap", 0.0);
	}
}, 0, 0);

print("FG1000 System Loaded");

