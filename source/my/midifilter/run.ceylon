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

shared interface Filter satisfies Receiver {
    shared formal variable Receiver next;
}

shared class AbstractFilter() satisfies Filter {
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

shared class AbstractTypedFilter() extends AbstractFilter() {
    shared default void sendShort(ShortMessage msg, Integer timeStamp) => super.send(msg, timeStamp);
    shared default void sendSysex(SysexMessage msg, Integer timeStamp) => super.send(msg, timeStamp);
    shared default void sendMeta(MetaMessage msg, Integer timeStamp) => super.send(msg, timeStamp);
    shared default void sendUnknown(MidiMessage? msg, Integer timeStamp) => super.send(msg, timeStamp);
    shared default actual void send(MidiMessage? msg, Integer timeStamp) {
        switch(msg)
        case(is ShortMessage) { sendShort(msg, timeStamp); }
        case(is SysexMessage) { sendSysex(msg, timeStamp); }
        case(is MetaMessage) { sendMeta(msg, timeStamp); }
        else { sendUnknown(msg, timeStamp); }
    }
}

shared class Log(String prefix) extends AbstractTypedFilter() {
    object help extends ShortMessage() {
        shared Integer getLength(ShortMessage msg) => getDataLength(msg.status);
    }

    shared actual void sendShort(ShortMessage msg, Integer timeStamp) {
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
            trace(timeStamp, "SHORT " + desc + args);
        }
        super.sendShort(msg, timeStamp);
    }
    shared actual void sendSysex(SysexMessage msg, Integer timeStamp) {
        trace(timeStamp, "SYSEX ``msg.status`` with ``msg.length - 1`` data bytes");
        super.sendSysex(msg, timeStamp);
    }
    shared actual void sendMeta(MetaMessage msg, Integer timeStamp) {
        trace(timeStamp, "META type ``msg.type``");
        super.sendMeta(msg, timeStamp);
    }
    shared actual void sendUnknown(MidiMessage? msg, Integer timeStamp) {
        if (exists msg) {
            trace(timeStamp, "UNKNOWN " + msg.string);
        } else {
            trace(timeStamp, "NULL");
        }
        super.sendUnknown(msg, timeStamp);
    }

    void trace(Integer timeStamp, String msg) {
        log.trace(prefix + ": ``timeStamp`` ``msg``");
    }
}

class Reverse() extends AbstractTypedFilter() {
    shared actual void sendShort(ShortMessage msg, Integer timeStamp) {
        ShortMessage newMsg;
        if (msg.command == noteOn || msg.command == noteOff) {
            newMsg = ShortMessage(msg.command, msg.channel, 129 - msg.data1, msg.data2);
        } else {
            newMsg = msg;
        }
        super.sendShort(newMsg, timeStamp);
    }
}

class BlinkaLillaStjärna() extends AbstractTypedFilter() {
    value notes = [ 60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60, 67, 67, 65, 65, 64, 64, 62, 67, 67, 65, 65, 64, 64, 62, 60, 60, 67, 67, 69, 69, 67, 65, 65, 64, 64, 62, 62, 60 ];
    variable value onPos = 0;
    variable value offPos = 0;
    shared actual void sendShort(ShortMessage msg, Integer timeStamp) {
        ShortMessage newMsg;
        if (msg.command == noteOn && msg.data2 != 0) {
            assert(exists note = notes[onPos++]);
            if (onPos == notes.size) { onPos = 0; }
            newMsg = ShortMessage(msg.command, msg.channel, note, msg.data2);
        } else if ((msg.command == noteOn && msg.data2 == 0) || msg.command == noteOff) {
            assert(exists note = notes[offPos++]);
            if (offPos == notes.size) { offPos = 0; }
            newMsg = ShortMessage(msg.command, msg.channel, note, msg.data2);
        } else {
            newMsg = msg;
        }
        super.sendShort(newMsg, timeStamp);
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
        log.error("Midi unavailable");
        printStackTrace(e);
        return;
    }

    value filters = [
    Log("In "),
    BlinkaLillaStjärna(), // Twinkle twinkle little star
    //Reverse(),
    Log("Out")
    ];
    value midiOutReceiver = midiOut.receiver;
    variable value next = midiOutReceiver;
    for (filter in filters.reversed) {
        filter.next = next;
        next = filter;
    }
    midiIn.transmitter.receiver = next;
    log.info("Midi through filter started ");

    value logKbd = Log("Kbd");
    logKbd.next = midiOutReceiver;
    connectKeyboard(logKbd);
    log.info("Keyboard midi out started");
    /*
     http://docs.oracle.com/javase/tutorial/sound/accessing-MIDI.html
     http://jsresources.org/faq_midi.html
     https://blogs.oracle.com/kashmir/entry/java_sound_api_3_midi
     */
}
