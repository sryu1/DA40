# Diamond DA40 NG fuel system
#
# (C) Mariusz Matuszek (MariuszXC) 2021-2022, Dan (dsatgh) 2024

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# For now: ('+' is done)
# + do fuel transfer with a constant pumping volume, when activated


###
### subsystem configuration:
###

var interval_sec         = 1.00  ; # timer callback interval (see NOTE below)

# computations:
var transfer_pump_flow   = 0.0498; # kg/s - fuel transfer pump capacity (from L to R tank) (normal: 227 l/h)

# NOTE (calculations error due to timing)
# with timer interval set to 1 second, the actual observed calling interval is 1.0x seconds, where:
#   x in {3..5} for a slow computer (4th gen Core i5 mobile), and
#   x in {0..2} for a fast computer (10th gen Core i5).
# This indicates, that average expected execution time of this script is around 25ms (around 3 JSBSim frames)
# This results in an error of 0 to 5%, average 2.5%
# Given that most configuration factors are honest approximations anyway, I think we can live with it.

# NOTE 2 (possible errors due to race between fuelsystem.nas and JSB engine model)
# JSBSim runs at 120Hz, which is ~8.33ms per frame.
# Economy cruise is at    5.1 gph -> 35.75 lbs/h = 4.50 g/s = 0.038 g/frame
# High speed cruise is at 8.4 gph -> 58.85 lbs/h = 7.42 g/s = 0.062 g/frame
# Max range is at         4.0 gph -> 28.04 lbs/h = 3.53 g/s = 0.029 g/frame
#
# Pumps pump ~50 g/s (xfer) or 37.4 g/s (emergency) - this is roughly 10x more than typical fuel consumption
#
# It is not possible to lock the property "consumables/fuel/tank[0]/level-kg" so it may happen
# that it will be updated in parallel from both this code and JSBSim engine model.
# This is a race condition.
# This may introduce a calculation error in left tank amount *during fuel transer only*
# Size of this error remains to be tested, but is not expected to be significant.
#
# Initial error estimate is (3 frame max consumptions) 0.186g / 37.4g ~= 0.5% (worst case)


# properties we use or set:
var ref_electric_master  =   props.globals.getNode("controls/electric/electric-master", 1) ;
var ref_tank_l_kg        =   props.globals.getNode("consumables/fuel/tank[0]/level-kg", 1) ;
var ref_tank_r_kg        =   props.globals.getNode("consumables/fuel/tank[1]/level-kg", 1) ;
var ref_tank_l_norm      =   props.globals.getNode("consumables/fuel/tank[0]/level-norm", 1) ;
var ref_tank_r_norm     =    props.globals.getNode("consumables/fuel/tank[1]/level-norm", 1) ;
var ref_fuel_xfer_cmd    =   props.globals.getNode("controls/electric/fuel-transfer", 1) ;
var ref_xfer_pump_active =   props.globals.getNode("da40/fuelsystem/electric-fuel-pump-transfer-active", 1) ;



##########################
#                        #
#  MAIN LOOP (CALLBACK)  #
#                        #
##########################

var update_fuel_system  = func() {

	var tank_l_kg       =   ref_tank_l_kg.getDoubleValue() ;
	var tank_r_kg       =   ref_tank_r_kg.getDoubleValue() ;


	## Fuel transfer - electric pump
	## ref. AMM, section 28-20-00, par. 4, page 5.
	## Pump is disabled if either L tank is full or R tank is empty

	# check preconditions to perform electric fuel pump fuel transfer

	if (ref_fuel_xfer_cmd.getBoolValue() and (ref_electric_master.getValue() > 0)
		and !(ref_tank_r_norm.getDoubleValue() < 0.02 or ref_tank_l_norm.getDoubleValue() > 0.98))
	{
		ref_xfer_pump_active.setBoolValue(1);
	} else {
		ref_xfer_pump_active.setBoolValue(0);
	}

	# if fuel xfer is active, modify tank levels

	if ( ref_xfer_pump_active.getBoolValue() ) {
		tank_l_kg = tank_l_kg + transfer_pump_flow ;
		tank_r_kg = tank_r_kg - transfer_pump_flow ;

		# set tank levels to newly calculated values
		ref_tank_l_kg.setDoubleValue(tank_l_kg);
		ref_tank_r_kg.setDoubleValue(tank_r_kg);
	}

};



###################
# CALLBACK SWITCH #
###################

# switch timer callback handling

var fuel_system_callback_switch = func () {
	update_fuel_system();
	run_settimer();
}


var run_settimer = func() {
	settimer(fuel_system_callback_switch, interval_sec);
}


# register a callback for after FDM is initialized
var listener_is_set = 0;

setlistener("/sim/signals/fdm-initialized", func {
	if (!listener_is_set) {
		listener_is_set = 1;
		fuel_system_callback_switch();
	}
});


# References

# Fuel valve -> emergency
#   fuel is pumped from AUX to MAIN at a rate 170 l/h (see POH 3.3.7)
# Fuel valve -> normal
#   fuel is pumped from AUX to MAIN at a rate 227 l/h (see POH 4A.5.10)
#   pumping is stopped automatically to avoid overfilling the main tank
#   pumping will resume automatically when fuel level drops, but only as long as AUX has fuel
#   'fuel transfer' light is illuminated only while the pump is running (see section 7.9.4)
#   NOTE: if 'fuel transfer' light starts to blink, fuel transfer pump must be switched off
