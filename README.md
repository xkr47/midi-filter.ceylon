# midi-filter.ceylon
Simple MIDI-through filter implemented in the Ceylon language.

Reads midi commands from the first MIDI IN device, filters them using selected filters and outputs the filtered commands to the first MIDI OUT device. The program also logs all input and all output commands.

# Requirements

An external MIDI-enabled keyboard with both MIDI IN and MIDI OUT e.g. capable of playback. Also you need to configure your keyboard to disable "Local Control" e.g. not to play back notes played on the keyboard, instead only play what comes from MIDI IN. Otherwise you will get duplicate tones.

# Installation & running

[Install Ceylon](http://ceylon-lang.org/download/) and then:

    ceylon compile
    ceylon run --flat-classpath my.midifilter

Then connect your midi cables to your keyboard and start playing :)

You can also import the project in [Eclipse with Ceylon IDE](http://ceylon-lang.org/documentation/current/ide/install/) - the flat-classpath setting should be set automatically.

Try commenting/uncommenting the various entries in the "value filters" list near the end of [run.ceylon](source/my/midifilter/run.ceylon).

Pull requests welcome :)

![screenshot](https://github.com/xkr47/midi-filter.ceylon/blob/master/screenshot.png)
