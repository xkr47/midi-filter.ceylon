import ceylon.collection {
    HashSet,
    HashMap,
    MutableMap
}
import ceylon.interop.java {
    javaClass
}
import ceylon.language {
    cprint=print
}

import java.awt {
    Dimension
}
import java.awt.event {
    KeyListener,
    KeyEvent
}
import java.lang {
    Runnable,
    JBoolean=Boolean,
    JLong=Long
}
import java.lang.reflect {
    Field
}

import javax.sound.midi {
    Receiver,
    ShortMessage {
        controlChange=\iCONTROL_CHANGE,
        programChange=\iPROGRAM_CHANGE,
        noteOff=\iNOTE_OFF,
        noteOn=\iNOTE_ON
    }
}
import javax.swing {
    SwingUtilities {
        invokeLater
    },
    JFrame {
        exitOnClose=\iEXIT_ON_CLOSE
    }
}

Field getRawCodeField() {
    value c = javaClass<KeyEvent>();
    value f = c.getDeclaredField("rawCode");
    javaClass<Field>().getMethod("setAccessible", JBoolean.\iTYPE).invoke(f, JBoolean(true));
    return f;
}
Field rawCodeField = getRawCodeField();
Integer getRawCode(KeyEvent e) {
    assert(is JLong v = rawCodeField.get(e));
    return v.longValue();
}

void connectKeyboard(Receiver receiver) {
    invokeLater(object satisfies Runnable & KeyListener {
        value pressed = HashSet<Integer>();

        Map<Integer,Integer> c(variable Integer off, Integer[] list, variable Integer off2, Integer[] list2) {
            value map = HashMap<Integer, Integer>{ entries = { for(k in list) k -> off++ }; };
            map.putAll({ for(k in list2) k -> off2++ });
            return map;
        }
        value keys = c(
            45+0, [ 50,66,94,/*38,*/52,39,53,40,54,/*41,*/55,42,56,43,57,44,58,/*45,*/59,46,60,47,61,/*48,*/62,51 ],
            45+21, [ 49,23,10,24,11,25,/*12,*/26,13,27,14,28,/*15,*/29,16,30,17,31,18,32,/*19,*/33,20,34,21,35,/*22,*/36 ]
        );

        value instruments = [
        [112,0], [113,0],
        [114,0], [115,0],
        [112,1], [113,1],
        [114,1], [115,1],
        [112,5], [112,88],
        [112,4], [118,4],
        [112,6], [115,6],
        [112,48], [113,49],
        [112,19], [113,19],
        [115,19], [114,19],
        [112,16], [113,16],
        [112,32], [114,32]
        ];

        variable value sendOnTwoChannels = false;
        variable value transpose = 0;
        value code2note = HashMap<Integer, Integer>();
        variable value stickyPedal = false;
        variable value instrumentHi = 0;
        variable value instrumentLo = 0;

        shared actual void run() {
            value frame = JFrame("MIDI Keyboard");
            frame.focusTraversalKeysEnabled = false;
            frame.defaultCloseOperation = exitOnClose;
            frame.size = Dimension(100, 100);
            frame.setLocationRelativeTo(null);
            frame.addKeyListener(this);
            frame.visible = true;
        }

        shared actual void keyPressed(KeyEvent? keyEvent) => key(keyEvent, true);
        shared actual void keyReleased(KeyEvent? keyEvent) => key(keyEvent, false);
        shared actual void keyTyped(KeyEvent? keyEvent) {}

        void send(Integer cmd, Integer data1, Integer data2 = 0) {
            receiver.send(ShortMessage(cmd, 0, data1, data2), -1);
            if (sendOnTwoChannels) {
                receiver.send(ShortMessage(cmd, 1, data1, data2), -1);
            }
        }

        void setInstrument() {
            value idx = instrumentLo.and(1) + instrumentHi * 2;
            value instrument = instruments[idx];
            if (exists instrument) {
                send(controlChange, 0, 0);
                send(controlChange, 32, instrument[0]);
                send(programChange, instrument[1]);
            }
        }

        void key(KeyEvent? keyEvent, Boolean keyPressed) {
            if (!exists keyEvent) { return; }
            value code = getRawCode(keyEvent);
            if (keyPressed) {
                if (!pressed.add(code)) { return; }
            } else {
                pressed.remove(code);
            }
            value note = keys[code] ;
            if (exists note) {
                Integer note2;
                if (keyPressed) {
                    note2 = note + transpose;
                    code2note.put(code, note2);
                } else {
                    assert(exists n = code2note.remove(code));
                    note2 = n;
                }
                send(keyPressed then noteOn else noteOff, note2, keyPressed then 64 else 0);
            } else {
                switch (code)
                case (9) {
                    exit();
                }
                case (64) { // left alt
                    if (keyPressed) {
                        stickyPedal = !stickyPedal;
                        send(controlChange, 64, stickyPedal then 127 else 0); // pedal
                    }
                }
                case (65) { // space
                    if (!stickyPedal || !keyPressed) {
                        stickyPedal = false;
                        send(controlChange, 64, keyPressed then 127 else 0); // pedal
                    }
                }
                case (105) { // right ctrl
                    if (keyPressed) {
                        sendOnTwoChannels = !sendOnTwoChannels;
                        cprint("2chan ``sendOnTwoChannels``");
                    }
                }
                case (82) { // KP -
                    if (keyPressed) {
                        ++transpose;
                        print("transpose ``transpose``");
                    }
                }
                case (86) { // KP +
                    if (keyPressed) {
                        --transpose;
                        print("transpose ``transpose``");
                    }
                }
                case (90) { // KP 0
                    if (keyPressed) {
                        instrumentHi = 0;
                        setInstrument();
                    }
                }
                case (87) { // KP 1
                    if (keyPressed) {
                        instrumentHi = 1;
                        setInstrument();
                    }
                }
                case (88) { // KP 2
                    if (keyPressed) {
                        instrumentHi = 2;
                        setInstrument();
                    }
                }
                case (89) { // KP 3
                    if (keyPressed) {
                        instrumentHi = 3;
                        setInstrument();
                    }
                }
                case (83) { // KP 4
                    if (keyPressed) {
                        instrumentHi = 4;
                        setInstrument();
                    }
                }
                case (84) { // KP 5
                    if (keyPressed) {
                        instrumentHi = 5;
                        setInstrument();
                    }
                }
                case (85) { // KP 6
                    if (keyPressed) {
                        instrumentHi = 6;
                        setInstrument();
                    }
                }
                case (79) { // KP 7
                    if (keyPressed) {
                        instrumentHi = 7;
                        setInstrument();
                    }
                }
                case (80) { // KP 8
                    if (keyPressed) {
                        instrumentHi = 8;
                        setInstrument();
                    }
                }
                case (81) { // KP 9
                    if (keyPressed) {
                        instrumentHi = 9;
                        setInstrument();
                    }
                }
                case (106) { // KP /
                    if (keyPressed) {
                        instrumentHi = 10;
                        setInstrument();
                    }
                }
                case (63) { // KP *
                    if (keyPressed) {
                        instrumentHi = 11;
                        setInstrument();
                    }
                }
                case (91) { // KP ,
                    if (keyPressed) {
                        instrumentLo = 1 - instrumentLo;
                        setInstrument();
                    }
                }
                else {
                    cprint("``keyPressed then "dn" else "up"`` ``code``");
                }
            }
        }

        suppressWarnings("expressionTypeNothing")
        void exit() {
            process.exit(0);
        }
    });
}
