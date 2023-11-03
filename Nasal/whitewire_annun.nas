#	This simulates the DA40-NG's White Wire Annunciator Panel
#	as described in ref. 2, section 31-51

#	Annunciator Categories
#	
#	Category		Aural Alert			Lights							Elements
#	1 Warning		Continuous until acknowledged	Red flashing (System + "Warning") until ack		Start, Doors, Alternator
#	2 Caution		Short or until acknowledged	Amber flashing (System + "Caution") until ack		Low Volts, Engine, ECU A, ECU B, Pitot, Low Fuel
#	3 Status		none				White steady						Fuel Trans, Glow


#	Set up Properties
var elapsed_time = props.globals.getNode("/sim/time/elapsed-sec", 1);

var annun = props.globals.initNode("/instrumentation/annunciator-panel");

var alert = annun.initNode( "alert", 0, "BOOL");

var light_path = annun.initNode("lights");

var flash_light = aircraft.light.new( "/instrumentation/annunciator-panel/lights/flash-property", [0.3, 0.3] );
setprop( "/instrumentation/annunciator-panel/lights/flash-property/enabled", 1 );

var lights = {
	warning:	light_path.getNode( "warning-state", 1 ),
	caution:	light_path.getNode( "caution-state", 1 ),
	start:		light_path.getNode( "start-state", 1 ),
	doors:		light_path.getNode( "doors-state", 1 ),
	low_volts:	light_path.getNode( "low-volts-state", 1 ),
	alternator:	light_path.getNode( "alternator-state", 1 ),
	ecu_a:		light_path.getNode( "ecu-a-state", 1 ),
	ecu_b:		light_path.getNode( "ecu-b-state", 1 ),
	fuel_trans:	light_path.getNode( "fuel-trans-state", 1 ),
	pitot:		light_path.getNode( "pitot-state", 1 ),
	low_fuel:	light_path.getNode( "low-fuel-state", 1 ),
	engine:		light_path.getNode( "engine-state", 1 ),
	glow:		light_path.getNode( "glow-state", 1 ),
	ack:		light_path.initNode( "ack", 0, "BOOL" ),
};

#	Properties checked by the system
var canopy = props.globals.getNode( "/da40/canopy-norm", 1 );
var pass_door = props.globals.getNode( "/da40/door-left-cmd", 1 );
var volts = props.globals.getNode( "/systems/electrical/outputs/annun", 1 );

var engine_props = {
	op:	props.globals.getNode( "/engines/engine/oil-pressure-bar", 1 ),
	ot:	props.globals.getNode( "/engines/engine/oil-temperature-degc", 1 ),
	ct:	props.globals.getNode( "/engines/engine/coolant-temperature-degc", 1 ),
	gt:	props.globals.getNode( "/engines/engine/gearbox-temperature-degc", 1 ),
	load:	props.globals.getNode( "/controls/engines/engine/throttle", 1 ),
};

var pitot_heat = props.globals.getNode( "/systems/electrical/outputs/pitot-heat", 1 );
var fuel_left = props.globals.getNode( "/consumables/fuel/tank[0]/level-gal_us", 1 );

#	State Variables
var selftest = 0;
var powered = 0;


var annun_controller = {
	new : func( cat, check_function ){
		m = { parents : [annun_controller] };
		m.cat = cat;
		m.check = check_function;
		return m;
	},
};


var new_annun = func( cat ){
	if( cat == 3 ){ return; }
	elsif( cat == 2 ){
		alert.setBoolValue( 1 );
		lights.caution.setIntValue( 2 );
		lights.ack.setBoolValue( 1 );
		settimer( func() { alert.setBoolValue(0); }, 2 );
	}elsif( cat == 1 ){
		alert.setBoolValue( 1 );
		lights.warning.setIntValue( 2 );
		lights.ack.setBoolValue( 1 );
	}else{ die( "Illegal Annun Category!" ) }
}

var old = {
	doors: 0,
	lowvolts: 0,
	pitot: 0,
	lowfuel: 0,
	engine: 0,
};
var annun_check = func{
	if( volts.getDoubleValue() < 9.0 ){ 
		powered = 0;
		return;
	}
	if( !powered ){
		selftest = 1;
		foreach( var el; keys( lights ) ){
			lights[el].setIntValue( 1 );
		}
		powered = 1;
		return;
	}
	if( selftest ){
		return;
	}
		
	
	var new_warn = 0;
	var new_caut = 0;
	
	if( !old.doors and ( canopy.getDoubleValue() > 0.01 or pass_door.getDoubleValue() > 0.01 ) ){
		new_warn = 1;
		lights.doors.setIntValue( 2 );
		old.doors = 1;
	} elsif( old.doors and !(canopy.getDoubleValue() > 0.01 or pass_door.getDoubleValue() > 0.01 ) ){
		lights.doors.setIntValue( 0 );
		old.doors = 0;
	}
	
	if( !old.lowvolts and volts.getDoubleValue() < 25.0 ){
		new_caut = 1;
		lights.low_volts.setIntValue( 2 );
		old.lowvolts = 1;
	} elsif( old.lowvolts and volts.getDoubleValue() >= 25.0 ){
		lights.low_volts.setIntValue( 0 );
		old.lowvolts = 0;
	}
	
	if( !old.pitot and pitot_heat.getDoubleValue() < 9.0 ){
		new_caut = 1;
		lights.pitot.setIntValue( 2 );
		old.pitot = 1;
	} elsif( old.pitot and pitot_heat.getDoubleValue() >= 9.0 ){
		lights.pitot.setIntValue( 0 );
		old.pitot = 0;
	}
	
	if( !old.lowfuel and fuel_left.getDoubleValue() < 3 ){
		new_caut = 1;
		lights.low_fuel.setIntValue( 2 );
		old.lowfuel = 1;
	} elsif( old.lowfuel and fuel_left.getDoubleValue() >= 3 ){
		lights.low_fuel.setIntValue( 0 );
		old.lowfuel = 0;
	}
	
	
	var op = engine_props.op.getDoubleValue();
	var ot = engine_props.ot.getDoubleValue();
	var ct = engine_props.ct.getDoubleValue();
	var gt = engine_props.gt.getDoubleValue();
	var load = engine_props.load.getDoubleValue();
	if( !old.engine and ( op < 2.5 or op > 6.0 or ot < 50 or ot > 135 or ct < 60 or ct > 95 or gt < 35 or gt > 115 or load > 0.92 ) ){
		new_caut = 1;
		lights.engine.setIntValue( 2 );
		old.engine = 1;
	} elsif( old.engine and op >= 2.5 and op <= 6.0 and ot >= 50 and ot <= 135 and ct >= 60 and ct <= 95 and gt >= 35 and gt <= 115 and load <= 0.92 ){
		lights.engine.setIntValue( 0 );
		old.engine = 0;
	}
	
	if( new_caut ){
		new_annun( 2 );
	}
	if( new_warn ){
		new_annun( 1 );
	}
	
	if( !old.doors ){
		lights.warning.setIntValue( 0 );
	}
	if( !old.lowvolts and !old.pitot and !old.lowfuel and !old.engine ){
		lights.caution.setIntValue( 0 );
	}
}
var annun_check_loop = maketimer( 0.5, annun_check );
annun_check_loop.simulatedTime = 1;
annun_check_loop.start();


var check_after_2 = func {
	print("Two seconds elapsed");
	if( ack_pressed ){
		more_than_2 = 1;
		# Start selftest while running
		selftest = 1;
		foreach( var el; keys( lights ) ){
			lights[el].setIntValue( 2 );
		}
		alert.setBoolValue( 1 );
	}
}
var check_after_2_timer = maketimer( 2.0, check_after_2 );
check_after_2_timer.simulatedTime = 1;
check_after_2_timer.singleShot = 1;

#	press: ack_press( 1 );
#	mod-up: ack_press( 0 );
var ack_pressed = 0;
var more_than_2 = 0;
var ack_press = func( a ) {
	if( a ){
		ack_pressed = 1;
		check_after_2_timer.start();
	} elsif( ack_pressed ) {
		lights.ack.setBoolValue( 0 );
		
		if( check_after_2_timer.isRunning ){
			check_after_2_timer.stop();
		}
		
		if( more_than_2 ){
			# print( "Long - Release" );
			more_than_2 = 0;
			if( selftest ){
				foreach( var el; keys( lights ) ){
					lights[el].setIntValue( 0 );
				}
				alert.setBoolValue( 0 );
				foreach( var el; keys( old ) ){
					old[el] = 0;
				}
				selftest = 0;
			}
		} else {
			# print( "Short" );
			if( selftest ){
				foreach( var el; keys( lights ) ){
					lights[el].setIntValue( 0 );
				}
				selftest = 0;
			} else {
				foreach( var el; keys( lights ) ){
					if( lights[el].getIntValue() == 2 ){
						lights[el].setIntValue( 1 );
					}
				}
				alert.setBoolValue( 0 );
			}
		}
	}
}
