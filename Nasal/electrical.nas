# Diamond DA40 NG Electrical System
# Bea Wolf (D-ECHO) 2020
# Reference(s) (see docs/references.md)	:
#			Ref. [1] chapter 7.10
#			Ref. [2] chapters 24, 33, 80

# based on turboprop engine electrical system by Syd Adams and C172S electrical system   ####

# Power Consumption References:		see instruments.md
#		Instrument		Power Consumption
#		Turn Coordinator	1.5A max starting, 0.35A max normal at 12V (assumed): 18W/4.2W		
#		ELT			??

# Basic props.nas objects
var electrical = props.globals.getNode("systems/electrical");
var electrical_sw = electrical.initNode("internal-switches");
var output = electrical.getNode("outputs");
var breakers = props.globals.initNode("/controls/circuit-breakers");
var controls = props.globals.getNode("/controls/electric");
var light_ctrl = props.globals.getNode("/controls/lighting");

var g1000 = props.globals.getNode("/options/g1000");

var alternator_load = 0.0;
var battery_load = {};

# Helper functions
var check_or_create = func ( prop, value, type ) {
	var obj = props.globals.getNode(prop, 1);
	if( obj.getValue() == nil ){
		return props.globals.initNode(prop, value, type);
	} else {
		return obj;
	}
}

#	Switches
var switches = {
	#	Electric Master Switch mapping: 0 = OFF; 1 = ON; 2 = START
	electric_master:	controls.initNode("electric-master",		0,	"INT"),
	engine_master:		controls.initNode("engine-master",		0,	"BOOL"),
	avionic_master:		controls.initNode("avionic-master",		0,	"BOOL"),
	essential_bus:		controls.initNode("essential-bus",		0,	"BOOL"),
	fuel_transfer:		controls.initNode("fuel-transfer",		0,	"BOOL"),

	pitot_heat:		props.globals.getNode("/controls/anti-ice/pitot-heat", 0, "BOOL"),
	#	Lights
	instrument_light:	light_ctrl.initNode("instrument-lights",	0.0,	"DOUBLE"),
	nav_light:		light_ctrl.initNode("nav-lights",		0,	"BOOL"),
	strobe_light:		light_ctrl.initNode("strobe",			0,	"BOOL"),
	landing_light:		light_ctrl.initNode("landing-lights",		0,	"BOOL"),
	taxi_light:		light_ctrl.initNode("taxi-light",		0,	"BOOL"),
	flood_light:		light_ctrl.initNode("flood-lights",		0,	"BOOL"),
};

#	Additional (not directly consumer-related) Circuit Breakers
var circuit_breakers = {
	main_bus_power:		breakers.initNode("main-bus-power",		1,	"BOOL"),
	main_tie:		breakers.initNode("main-tie",			1,	"BOOL"),
	main_bus_start:		breakers.initNode("main-bus-start",		1,	"BOOL"),
	avionic_bus:		breakers.initNode("avionic-bus",		1,	"BOOL"),
	ess_tie:		breakers.initNode("essential-tie",		1,	"BOOL"),
	master_control:		breakers.initNode("master-control",		1,	"BOOL"),
};

#	Internal (virtual) switches
var int_switches = {
	strobe_light:		props.globals.initNode("/sim/model/lights/strobe/state",	0,	"BOOL"),
};

var delta_sec	=	props.globals.getNode("sim/time/delta-sec");

## Lights
#				EXTERIOR
#	Landing Lights
#		systems/electrical/outputs/landing-lights
#	Taxi Lights
#		systems/electrical/outputs/taxi-lights
#	Navigation Lights
#		systems/electrical/outputs/navigation-lights
#	Strobe Lights
#		systems/electrical/outputs/anti-collision-lights
#		https://www.youtube.com/watch?v=AKfkJbK9C4k: 	three short flashes, then about 1-2 seconds pause
#	Instrument Lights
#		systems/electrical/outputs/instrument-lights
#	Flood Lights
#		systems/electrical/outputs/flood-lights



var strobeLight = aircraft.light.new("/sim/model/lights/strobe", [0.08, 0.08, 0.08, 0.08, 0.08, 1.7, 0.08], switches.strobe_light);


#	TODO calculate battery temperature correctly
var BatteryClass = {
	new : func( switch, volt, amps, amp_hours, charge_percent, charge_amps, n){
		m = { 
			parents : [BatteryClass],
			switch:		props.globals.initNode(switch, 1, "BOOL"),
			temp:		electrical.initNode("battery-temperature["~n~"]", 15.0, "DOUBLE"),
			ideal_volts:	volt,
			ideal_amps:	amps,
			volt_p:		electrical.initNode("battery-volts["~n~"]", 0.0, "DOUBLE"),
			amp_hours:	amp_hours,
			charge_percent:	charge_percent, 
			charge_amps:	charge_amps,
		};
		return m;
	},
	apply_load : func( load ) {
		var dt = delta_sec.getDoubleValue();
		if( me.switch.getBoolValue() ){
			var amphrs_used = load * dt / 3600.0;
			var percent_used = amphrs_used / me.amp_hours;
			me.charge_percent -= percent_used;
			if ( me.charge_percent < 0.0 ) {
				me.charge_percent = 0.0;
			} elsif ( me.charge_percent > 1.0 ) {
				me.charge_percent = 1.0;
			}
			var output =me.amp_hours * me.charge_percent;
			return output;
		}else return 0;
	},
	
	get_output_volts : func {
		if( me.switch.getBoolValue() ){
			var x = 1.0 - me.charge_percent;
			var tmp = -(3.0 * x - 1.0);
			var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
			var output =me.ideal_volts * factor;
			me.volt_p.setDoubleValue( output );
			return output;
		}else return 0;
	},
	
	get_output_amps : func {
		if( me.switch.getBoolValue() ){
			var x = 1.0 - me.charge_percent;
			var tmp = -(3.0 * x - 1.0);
			var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
			var output =me.ideal_amps * factor;
			return output;
		}else return 0;
	}
};

# var alternator = AlternatorClass.new( "/engines/engine[0]/rpm", 800.0, 14.0, 12.0 );
##
# Alternator model class.
#
var AlternatorClass = {
	new: func ( rpm_source, rpm_threshold, ideal_volts, ideal_amps ) {
		var obj = { parents : [AlternatorClass],
				rpm_source : props.globals.getNode( rpm_source, 1 ),
				rpm_threshold : rpm_threshold,
				ideal_volts : ideal_volts,
				ideal_amps : ideal_amps };
		obj.rpm_source.setDoubleValue( 0.0 );
		return obj;
	},
	apply_load: func( amps ){
		var dt = delta_sec.getDoubleValue();
		
		setprop("/systems/electrical/alternator-amps", amps );
		
		# Computes available amps and returns remaining amps after load is applied
		# Scale alternator output for rpms < 800.  For rpms >= 800
		# give full output.  This is just a WAG, and probably not how
		# it really works but I'm keeping things "simple" to start.
		var factor = me.rpm_source.getDoubleValue() / me.rpm_threshold;
		if ( factor > 1.0 ) {
			factor = 1.0;
		}
		
		# print( "alternator amps = ", me.ideal_amps * factor );
		var available_amps = me.ideal_amps * factor;
		return available_amps - amps;
	},
	get_output_volts: func {
		# Return output volts based on rpm
		
		# scale alternator output for rpms < 800.  For rpms >= 800
		# give full output.  This is just a WAG, and probably not how
		# it really works but I'm keeping things "simple" to start.
		var rpm = me.rpm_source.getDoubleValue();
		if( rpm < 100 ){
			return 0.0;
		}
		var factor = rpm / me.rpm_threshold;
		if ( factor > 1.0 ) {
			factor = 1.0;
		}
		# print( "alternator volts = ", me.ideal_volts * factor );
		return me.ideal_volts * factor;
	},
	get_output_amps: func {
		# Return output amps available based on rpm.
		
		# scale alternator output for rpms < 800.  For rpms >= 800
		# give full output.  This is just a WAG, and probably not how
		# it really works but I'm keeping things "simple" to start.
		var factor = me.rpm_source.getDoubleValue() / me.rpm_threshold;
		if ( factor > 1.0 ) {
			factor = 1.0;
		}
		
		# print( "alternator amps = ", ideal_amps * factor );
		return me.ideal_amps * factor;
	},

};

var main_battery = BatteryClass.new("/systems/electrical/main-battery/serviceable", 24.0, 30, 13.6, 1.0, 7.0, 0);
var ECU_batteries = [
	BatteryClass.new( "/systems/electrical/ecu-battery[0]/serviceable", 12.0, 30, 7.2, 1.0, 7.0, 1 ),
	BatteryClass.new( "/systems/electrical/ecu-battery[1]/serviceable", 12.0, 30, 7.2, 1.0, 7.0, 2 ),
];
var emergency_battery = BatteryClass.new("/systems/electrical/emergency-battery/serviceable", 24.0, 30, 13.6, 1.0, 0.0, 3);	# capacity?? supplies AI + flood light for 1 hour

var alternator = AlternatorClass.new( "/engines/engine[0]/rpm", 800.0, 28.0, 70.0 );

#	Consumer Class
#		Functions:
#			* power: takes bus_volts, applies to relevant outputs/ property and returns electrical load
#			* automatically trips its circuit breaker when maximum load is exceeded
var consumer = {
	new: func( name, switch, watts, cb_max ){
		m = { parents : [consumer] };
		m.cb = breakers.initNode(name, 1, "BOOL");
		m.switch_type = "none";
		if( switch != nil ){
			m.switch = switch;
			if ( switch.getType() == "DOUBLE" or switch.getType() == "FLOAT" ) {
				m.switch_type = "double";
			} else if ( switch.getType() == "BOOL" ) {
				m.switch_type = "bool";
			} else {
				die("Consumer (non-int) switch of unsupported type: "~ switch.getType() ~ "!");
			}
		} else {
			m.switch = nil;
		}
		m.output = output.initNode(name, 0.0, "DOUBLE");
		m.watts = watts;
		m.cb_max = cb_max;
		return m;
	},
	power: func( bus_volts ){
		if( me.cb.getBoolValue() and bus_volts != 0.0 ){
			if ( me.switch_type == "none" or ( me.switch_type == "bool" and me.switch.getBoolValue() ) ) {
				me.output.setDoubleValue( bus_volts );
				# if( me.watts/bus_volts > me.cb_max ){
				# 	me.cb.setBoolValue( 0 );
				# 	return 0.0;
				# }
				return me.watts / bus_volts;
			} else if ( me.switch_type == "double" ) {
				me.output.setDoubleValue( bus_volts * me.switch.getDoubleValue() );
				# if( me.watts / bus_volts * me.switch.getDoubleValue() > me.cb_max ){
				# 	me.cb.setBoolValue( 0 );
				# 	return 0.0;
				# }
				return me.watts / bus_volts * me.switch.getDoubleValue();
			} else {
				me.output.setDoubleValue( 0.0 );
				return 0.0;
			}
		} else {
			me.output.setDoubleValue( 0.0 );
			return 0.0;
		}
	},
};
# Consumer with support for integer switches
var consumer_int = {
	new: func( name, switch, watts, int, mode ){
		m = { parents : [consumer_int] };
		m.cb = breakers.initNode(name, 1, "BOOL");
		if ( switch.getType() == "INT" ) {
			m.switch = switch;
			m.int = int;
			# Mode: 0 means "=="; 1 means "!="
			if( mode != nil ){
				m.mode = mode;
			} else {
				m.mode = 0;
			}
		} else {
			die("Consumer (int) switch of unsupported type: "~ switch.getType() ~ "!");
		}
		m.output = output.initNode(name, 0.0, "DOUBLE");
		m.watts = watts;
		return m;
	},
	power: func( bus_volts ){
		if( me.cb.getBoolValue() and bus_volts != 0.0 ){
			if ( ( ( me.mode == 0 and me.switch.getIntValue() == me.int ) or ( me.mode == 1 and me.switch.getIntValue() != me.int ) ) ) {
				me.output.setDoubleValue( bus_volts );
				return me.watts / bus_volts;
			} else {
				me.output.setDoubleValue( 0.0 );
				return 0.0;
			}
		} else {
			me.output.setDoubleValue( 0.0 );
			return 0.0;
		}
	},
};

var amps = {};

#	Electrical Bus Class
var bus = {
	new: func( name, on_update, consumers ) {
		m = {	
			parents: [bus],
			name: name,
			volts: check_or_create("systems/electrical/bus/" ~ name ~ "-volts", 0.0, "DOUBLE"),
			serviceable: check_or_create("systems/electrical/bus/" ~ name ~ "-serviceable", 1, "BOOL"),
			on_update: on_update,
			bus_volts: 0.0,
			consumers: consumers,
		};
		amps.name = 0.0;	# register amps
		return m;
	},
	update_consumers: func () {
		#print("Update consumers of bus "~ me.name);
		load = 0.0;
		foreach( var c; me.consumers ) {
			load += c.power( me.bus_volts );
		}
		return load;
	},
};


#	Hot Battery Bus
#		directly connected to main battery
#		powers:
#			power plug
#			ELT
var hot_battery_bus = bus.new(
	"hot-battery-bus",
	func() {
		if( me.serviceable.getBoolValue() ){
			me.bus_volts = main_battery.get_output_volts();
		} else {
			me.bus_volts = 0.0;
		}
		
		var load = me.update_consumers();
		
		battery_load.main += load;
		
		me.volts.setDoubleValue( me.bus_volts );
	},
	[
		# TODO Circuit Breaker max load?!
		consumer.new( "aux-power-plug", nil, 0.0, 5 ),	# when no device is plugged in; 5A max ref. [2] chapter 24-00-00 page 2
		consumer.new( "elt", nil, 0.1, 5 ),		# TODO: ELT electrical load?
	],
);

#	Battery Bus 1
#		connected to main battery via battery relay (ELECTRIC MASTER key switch)
#		connected to external power port
#		powers:
#			Battery Bus 2
#			Starter
var battery_bus_1 = bus.new(
	"battery-bus-1",
	func() {
		me.src = "";
		if( me.serviceable.getBoolValue() and switches.electric_master.getIntValue() > 0 ){
			me.bus_volts = main_battery.get_output_volts();
			if( battery_bus_2.bus_volts > me.bus_volts and battery_bus_2.src != me.name ){
				me.bus_volts = battery_bus_2.bus_volts;
				me.src = "alternator";
			} else {
				me.src = "battery_main";
			}
		} else {
			me.bus_volts = 0.0;
		}
		var load = me.update_consumers();
		
		if( me.src == "alternator" ){
			alternator_load += load;
		} else {
			battery_load.main += load;
		}
		
		me.volts.setDoubleValue( me.bus_volts );
	},
	[
		consumer_int.new( "starter", switches.electric_master, 0.1, 2, 0 ),	# TODO: starter electrical load?
	],
);

#	Battery Bus 2
#		connected to battery bus 1
#		powers:
#			ECU bus
#			Main bus
var battery_bus_2 = bus.new(
	"battery-bus-2",
	func( ){
		me.src = "";
		
		if( me.serviceable.getBoolValue() ){
			me.bus_volts = battery_bus_1.bus_volts;
			if( ecu_bus.bus_volts > ( me.bus_volts - 0.5 ) and ecu_bus.bus_volts > 0 and ecu_bus.src != me.name ){
				me.bus_volts = ecu_bus.bus_volts;
				me.src = "alternator";
			} else {
				me.src = "battery-bus-1";
			}
		} else {
			me.bus_volts = 0.0;
		}
		
		var load = 0.0;
		
		load += main_bus.on_update( me.bus_volts );
		if( switches.essential_bus.getBoolValue() ){
			load += essential_bus.on_update( me.bus_volts );
		}
		
		me.volts.setDoubleValue( me.bus_volts );
		
	#	print("Battery Bus 2 Load: " ~ load );
	#	print("Battery Bus 2 Source: " ~ me.src );
		if( me.src == "alternator" ){
			alternator_load += load;
		} else {
			battery_load.main += load;
		}
	},
	[],
);

#	ECU Bus
#		connected to battery bus 2
#		connected to alternator
#		connected to ECU backup battery
#		powers:
#			ECU A
#			ECU B
#			ECU A Fuel Pump
#			ECU B Fuel Pump
var ecu_bus = bus.new(
	"ecu-bus",
	func( ){
		me.src = "";
		me.bus_volts = 0.0;
		if( me.serviceable.getBoolValue() ){
			var alternator_volts = alternator.get_output_volts();
			if( alternator_volts > 0.0 ){
				me.bus_volts = alternator_volts;
				me.src = "alternator";
			}
			if( ( battery_bus_2.bus_volts - 0.5 ) > me.bus_volts ) {
				me.bus_volts = battery_bus_2.bus_volts;
				me.src = "battery-bus-2";
			}
		}
		
		var load = me.update_consumers();
		
		me.volts.setDoubleValue( me.bus_volts );
		
	#	print("ECU Bus Load: " ~ load );
	#	print("ECU Bus Volts: " ~ me.bus_volts );
	#	print("ECU Bus Source: " ~ me.src );
		
		if( me.src == "alternator" ){
			alternator_load += load;
		} else {
			battery_load.main += load;
		}
	},
	[
		#TODO: ECU and ECU Fuel Pump electrical load?
		consumer.new( "ecu-a", switches.engine_master, 100, 20 ),
		consumer.new( "ecu-b", switches.engine_master, 100, 20 ),
		consumer.new( "ecu-fuel-pump-a", switches.engine_master, 50, 7.5 ),
		consumer.new( "ecu-fuel-pump-b", switches.engine_master, 50, 7.5 ),
	],
);

#	Main Bus
#		connected to battery bus 2 when essential bus switch is OFF
#		powers:
#			own consumers
#			avionics bus
#			essential bus (when essential bus switch is OFF)
var main_bus = bus.new(
	"main-bus",
	func( bv ){
		if( me.serviceable.getBoolValue() and !switches.essential_bus.getBoolValue() and circuit_breakers.main_bus_power.getBoolValue() ){
			me.bus_volts = bv;
		} else {
			me.bus_volts = 0.0;
		}
		
		var load = me.update_consumers();
		if( main_essential_tie ){
			load += essential_bus.on_update( me.bus_volts );
		}
		
		me.volts.setDoubleValue( me.bus_volts );
		
	#	print("Main Bus Load: " ~ load );
		return load;
	},
	[
		# TODO: Electrical load
		consumer.new( "instrument-lights", switches.instrument_light, 5, 5 ),
		consumer.new( "taxi-map-lights", switches.taxi_light, 35, 5 ),
		consumer.new( "navigation-lights", switches.nav_light, 40, 5 ),
		consumer.new( "strobe-lights", int_switches.strobe_light, 40, 5 ),
		# TODO: starter?! (cb max 5A, G1000 variant: max 10A)
		consumer.new( "xfer-pump", switches.fuel_transfer, 40, 5),
	],
);

# Version-specific consumers:
if( g1000.getBoolValue() ){
	append( main_bus.consumers, consumer.new( "mfd", nil, 0.1, 5 ) );
	append( main_bus.consumers, consumer.new( "av-cdu-fan", nil, 0.1, 3 ) );
	
} else {
	append( main_bus.consumers, consumer.new( "fan-oat", nil, 0.1, 3 ) );
	append( main_bus.consumers, consumer.new( "turn-coordinator", nil, 0.1, 3 ) );
	append( main_bus.consumers, consumer.new( "DG", nil, 0.1, 3 ) );
}

#	Avionic Bus
#		connected to essential bus (ref. [2] chapter 24-00-00 page 3)
#		powers:
#			own consumers
var avionic_bus = bus.new(
	"avionic-bus",
	func( bv ) {
		if( me.serviceable.getBoolValue() and switches.avionic_master.getBoolValue() and circuit_breakers.avionic_bus.getBoolValue() ){
			me.bus_volts = bv;
		} else {
			me.bus_volts = 0.0;
		}
		
		var load = me.update_consumers();
		
		me.volts.setDoubleValue( me.bus_volts );
		
		return load;
	},
	[
		# TODO: Electrical load
		consumer.new( "audio", nil, 0.1, 1 ),
		consumer.new( "comm[1]", nil, 0.1, 5 ),
		consumer.new( "autopilot", nil, 0.1, 5 ),
	],
);


# Version-specific consumers:
if( g1000.getBoolValue() ){
	append( avionic_bus.consumers, consumer.new( "gps-nav[1]", nil, 0.1, 5 ) );
	append( avionic_bus.consumers, consumer.new( "dme", nil, 0.1, 2 ) );
	append( avionic_bus.consumers, consumer.new( "wx500", nil, 0.1, 3 ) );
	
} else {
	append( avionic_bus.consumers, consumer.new( "gps", nil, 0.1, 2 ) );
	append( avionic_bus.consumers, consumer.new( "comm[0]", nil, 0.1, 5 ) );
	append( avionic_bus.consumers, consumer.new( "nav[0]", nil, 0.1, 5 ) );
	append( avionic_bus.consumers, consumer.new( "nav[1]", nil, 0.1, 5 ) );
	append( avionic_bus.consumers, consumer.new( "transponder", nil, 0.1, 5 ) );
}

#	Essential Bus
#		connected to main bus when essential bus switch is OFF
#		connected to battery bus 2 when essential bus switch is ON
#		powers:
#			own consumers
var essential_bus = bus.new(
	"essential-bus",
	func( bv ) {
		var src = "";
		if( me.serviceable.getBoolValue() ) {
			me.bus_volts = bv;
		} else {
			me.bus_volts = 0.0;
		}
		
		var load = me.update_consumers();
		load += avionic_bus.on_update( me.bus_volts );
		
		me.volts.setDoubleValue( me.bus_volts );
		
	#	print("Essential Bus Load: " ~ load );
		return load;
	},
	[
		# TODO: Electrical load
		consumer.new( "horizon", nil, 0.1, 3 ),
		consumer.new( "flaps", nil, 0.1, 5 ),
		consumer.new( "engine-instruments", nil, 0.1, 5 ),
		consumer.new( "pitot-heat", switches.pitot_heat, 100, 10 ),
		consumer.new( "landing-lights", switches.landing_light, 35, 5 ),
		consumer.new( "flood-lights", switches.flood_light, 3, 3 ),
	],
);

# Version-specific consumers:
if( g1000.getBoolValue() ){
	append( essential_bus.consumers, consumer.new( "ahrs", nil, 0.1, 5 ) );
	append( essential_bus.consumers, consumer.new( "adc", nil, 0.1, 5 ) );
	append( essential_bus.consumers, consumer.new( "comm[0]", nil, 0.1, 5 ) );
	append( essential_bus.consumers, consumer.new( "gps-nav[0]", nil, 0.1, 5 ) );
	append( essential_bus.consumers, consumer.new( "transponder", nil, 0.1, 5 ) );
	append( essential_bus.consumers, consumer.new( "pfd", nil, 0.1, 5 ) );
} else {
	append( essential_bus.consumers, consumer.new( "annun", nil, 0.1, 3 ) );
	
}


var flaps_power = props.globals.getNode("systems/electrical/outputs/flaps");
var cmd_flaps = props.globals.getNode("controls/flight/flaps");
var int_flaps = props.globals.getNode("controls/flight/flaps-int");

var main_essential_tie = 0;

var update_electrical = func {
	alternator_load = 0.0;
	battery_load = {
		main:	0.0,
		ecu: [
			0.0,
			0.0
		],
		emergency: 0.0,
	};
	
	if( !switches.essential_bus.getBoolValue() and circuit_breakers.main_tie.getBoolValue() and circuit_breakers.ess_tie.getBoolValue() and circuit_breakers.master_control.getBoolValue() ){
		main_essential_tie = 1;
	} else {
		main_essential_tie = 0;
	}
	
	hot_battery_bus.on_update();
	ecu_bus.on_update();
	battery_bus_1.on_update();
	battery_bus_2.on_update();
	
	# print( alternator_load );
	if( alternator.apply_load( alternator_load ) < 0 ){
		print("Alternator over-load!");
	}
	main_battery.apply_load( battery_load.main );
	ECU_batteries[0].apply_load( battery_load.ecu[0] );
	ECU_batteries[1].apply_load( battery_load.ecu[1] );
	emergency_battery.apply_load( battery_load.emergency );
	
	# Flaps only operate when electrically powered:
	if( flaps_power.getDoubleValue() > 15 and cmd_flaps.getDoubleValue() != int_flaps.getDoubleValue() ){
		int_flaps.setDoubleValue( cmd_flaps.getDoubleValue() );
	}
}

var electrical_updater = maketimer( 0.0, update_electrical );
electrical_updater.simulatedTime = 1;
electrical_updater.start();

# TODO turn indicator watts calculation not working as intended
#var turn_indicator_spin = props.globals.getNode("/instrumentation/turn-indicator/spin");
#
#var check_watts = func {
#	var tc_spin = turn_indicator_spin.getDoubleValue();
#
#	if( tc_spin == 1.0 ){
#		main_bus.consumers[1].watts = 4.2;
#		# print( "Turn Coordinator running" );
#	} else {
#		main_bus.consumers[1].watts = 18;
#		# print( "Turn Coordinator starting" );
#	}
#}
#
#var watts_updater = maketimer( 0.1, check_watts );
#watts_updater.simulatedTime = 1;
#watts_updater.start();

#	Disable non-existent instruments
setlistener("/options/ifr-conventional", func( ifr ) {
	if( ifr.getBoolValue() ){
		avionic_bus.consumers[3].watts = 0.1;
		avionic_bus.consumers[5].watts = 0.1;
	} else {
		avionic_bus.consumers[3].watts = 0.0;
		avionic_bus.consumers[5].watts = 0.0;
	}
});
