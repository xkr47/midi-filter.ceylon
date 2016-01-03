import ceylon.interop.java {
    javaClassFromInstance
}

import javax.sound.midi {
    ShortMessage {
        midiTimeCode = \iMIDI_TIME_CODE,
        songPositionPointer = \iSONG_POSITION_POINTER,
        songSelect = \iSONG_SELECT,
        tuneRequest = \iTUNE_REQUEST,
        endOfExclusive = \iEND_OF_EXCLUSIVE,
        timingClock = \iTIMING_CLOCK,
        start = \iSTART,
        cont = \iCONTINUE,
        stop = \iSTOP,
        activeSensing = \iACTIVE_SENSING,
        systemReset = \iSYSTEM_RESET,
        // commands with channels:
        noteOff = \iNOTE_OFF,
        noteOn = \iNOTE_ON,
        polyPressure = \iPOLY_PRESSURE,
        controlChange = \iCONTROL_CHANGE,
        programChange = \iPROGRAM_CHANGE,
        channelPressure = \iCHANNEL_PRESSURE,
        pitchBend = \iPITCH_BEND
    },
    ...
}
import ceylon.logging {
    Logger,
    logger,
    writeSimpleLog,
    addLogWriter,
    defaultPriority,
    trace
}

Logger log = logger(`package`);

// Filters

interface Filter satisfies Receiver {
    shared formal variable Receiver next;
}

class AbstractFilter() satisfies Filter {
    variable Receiver? _next = null;
    shared actual Receiver next {
        assert (exists n = _next);
        return n;
    }
    assign next {
        _next = next;
    }

    shared default actual void send(MidiMessage? midiMessage, Integer timeStamp) => next.send(midiMessage, timeStamp);
    shared default actual void close() => next.close();
}

class AbstractTypedFilter() extends AbstractFilter() {
    shared default actual void send(MidiMessage? midiMessage, Integer timeStamp) {

    }
}

class Log(String prefix) extends AbstractFilter() {
    object help extends ShortMessage() {
        shared Integer getLength(ShortMessage msg) => getDataLength(msg.status);
    }
    shared actual void send(MidiMessage? msg, Integer timeStamp) {
        /*
        if (exists msg, msg.status != timingClock && msg.status != activeSensing) {
            log.trace(prefix + ": ``timeStamp`` ``msg.status``");
        }
         */
        switch(msg)
        case (null) {
            log.trace(prefix + ": ``timeStamp`` NULL");
        }
        case(is ShortMessage) {
            variable Boolean skip = false;
            String desc;
            value status = msg.status;
            if (status < #F0 && status >= #80) {
                String cmd;
                value command = msg.command;
                if (command == noteOff) { cmd = "noteOff"; }
                else if (command == noteOn) { cmd = "noteOn"; }
                else if (command == polyPressure) { cmd = "polyPressure"; }
                else if (command == controlChange) { cmd = "controlChange"; }
                else if (command == programChange) { cmd = "programChange"; }
                else if (command == channelPressure) { cmd = "channelPressure"; }
                else if (command == pitchBend) { cmd = "pitchBend"; }
                else { cmd = "unknown ``command``"; }
                desc = "``cmd`` channel ``msg.channel``";
            } else {
                if (status == midiTimeCode) { desc = "midiTimeCode"; }
                else if (status == songPositionPointer) { desc = "songPositionPointer"; }
                else if (status == songSelect) { desc = "songSelect"; }
                else if (status == tuneRequest) { desc = "tuneRequest"; }
                else if (status == endOfExclusive) { desc = "endOfExclusive"; }
                else if (status == timingClock) { desc = "timingClock"; skip = true; }
                else if (status == start) { desc = "start"; }
                else if (status == cont) { desc = "cont"; }
                else if (status == stop) { desc = "stop"; }
                else if (status == activeSensing) { desc = "activeSensing"; skip = true; }
                else if (status == systemReset) { desc = "systemReset"; }
                else { desc = "unknown ``status``"; }
            }
            String args;
            switch(help.getLength(msg))
            case(0) {args = ""; }
            case(1) {args = " " + msg.data1.string;}
            case(2) {args = " " + msg.data1.string + ", " + msg.data2.string;}
            else {args = "?";}
            if (!skip) {
                log.trace(prefix + ": ``timeStamp`` SHORT " + desc + args);
            }
        }
        case(is SysexMessage) {
            log.trace(prefix + ": ``timeStamp`` SYSEX ``msg.status`` with ``msg.length - 1`` data bytes");
        }
        case(is MetaMessage) {
            log.trace(prefix + ": ``timeStamp`` META type ``msg.type``");
        }
        else {
            log.trace(prefix + ": ``timeStamp`` unknown " + msg.string);
        }
        super.send(msg, timeStamp);
    }
}

// main app

[MidiDevice, MidiDevice] getDevices() {
    value aInfos = MidiSystem.midiDeviceInfo.array;
    variable MidiDevice? midiIn = null;
    variable MidiDevice? midiOut = null;
    for (i in 0:aInfos.size) {
        assert (exists info = aInfos[i]);
        try
        {
            value device = MidiSystem.getMidiDevice(info);
            value bAllowsInput = device.maxTransmitters != 0;
            value bAllowsOutput = device.maxReceivers != 0;
            value isSynthesizer = device is Synthesizer;
            value isSequencer = device is Sequencer;
            if (!isSynthesizer && !isSequencer) {
                if (bAllowsOutput) {
                    midiOut = device;
                }
                if (bAllowsInput) {
                    midiIn = device;
                }
            }
            print("``i``  ``bAllowsInput then "IN " else "   "`` ``bAllowsOutput then "OUT " else "    "`` name=``info.name ``, vendor=``info.vendor ``, version=``info.version ``, description=``info.description`` class=``javaClassFromInstance(device).name``" +
                "``device is Synthesizer then " SY" else ""``" +
                    "``device is Sequencer then " SQ" else ""``");
        }
        catch (MidiUnavailableException e)
        {
            // device is obviously not available...
            printStackTrace(e);
        }
    }
    if (exists i = midiIn, exists o = midiOut) {
        return [i, o];
    }
    throw Exception("No MIDI devices available");
}

shared void run() {
    addLogWriter(writeSimpleLog);
    defaultPriority = trace;

    value [midiIn, midiOut] = getDevices();
    try {
        midiIn.open();
        if (midiIn != midiOut) {
            midiOut.open();
        }
    } catch (MidiUnavailableException e) {
        log.error("Midi unavailable", e);
        return;
    }

    value filters = [
        Log("In"),
        //Reverse(),
        Log("Out")
    ];
    variable value next = midiOut.receiver;
    for (filter in filters.reversed) {
        filter.next = next;
        next = filter;
    }
    midiIn.transmitter.receiver = next;
    /*
     http://docs.oracle.com/javase/tutorial/sound/accessing-MIDI.html
     http://jsresources.org/faq_midi.html
     https://blogs.oracle.com/kashmir/entry/java_sound_api_3_midi
     */
}
