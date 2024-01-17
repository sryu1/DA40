var disengage_starter_timer = maketimer(2, func { props.globals.setIntValue("/controls/electric/electric-master", 1); });
    disengage_starter_timer.singleShot = 1;
if( getprop("/options/g1000") ){
    var autostart = func {
        props.globals.setBoolValue("/controls/electric/avionic-master", 1);
        props.globals.setBoolValue("/controls/electric/battery-switch", 1);
        props.globals.setBoolValue("/controls/electric/engine-master-cover", 1);
        props.globals.setBoolValue("/controls/electric/engine-master", 1);
        props.globals.setBoolValue("/controls/electric/engine-master-cover", 0);
        props.globals.setDoubleValue("/controls/engines/engine/throttle", 0.15);
        props.globals.setIntValue("/controls/electric/electric-master", 2);
        props.globals.setDoubleValue("/controls/lighting/instrument-lights", 0.8);
        props.globals.setDoubleValue("/controls/lighting/flood-lights", 0.5);
        props.globals.setBoolValue("/controls/lighting/nav-lights", 1);
        props.globals.setBoolValue("/controls/lighting/strobe", 1);
        disengage_starter_timer.start();
    }
} else {
    var autostart = func {
        props.globals.setBoolValue("/controls/electric/avionic-master", 1);
        props.globals.setBoolValue("/controls/lighting/strobe", 1);
        props.globals.setBoolValue("/controls/lighting/nav-lights", 1);
        props.globals.setDoubleValue("/controls/lighting/instrument-lights", 0.8);
        props.globals.setDoubleValue("/controls/lighting/flood-lights", 0.2);
        props.globals.setBoolValue("/controls/electric/engine-master", 1);
        props.globals.setDoubleValue("/controls/engines/engine/throttle", 0.15);
        props.globals.setIntValue("/controls/electric/electric-master", 2);
        disengage_starter_timer.start();
    }
}