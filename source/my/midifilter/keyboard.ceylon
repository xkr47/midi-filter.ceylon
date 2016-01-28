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

        variable value sendOnTwoChannels = false;
        variable value transpose = 0;
        value code2note = HashMap<Integer, Integer>();
        variable value stickyPedal = false;

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
