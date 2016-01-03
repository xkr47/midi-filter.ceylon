# midi-filter.ceylon
Simple MIDI-through filter implemented in the Ceylon language.

Reads midi commands from the first MIDI IN device, filters them using selected filters and outputs the filtered commands to the first MIDI OUT device.

# Requirements

An external MIDI-enabled keyboard with both MIDI IN and MIDI OUT e.g. capable of playback. Also you need to configure your keyboard to disable "Local Control" e.g. not to play back notes played on the piano, instead only play what comes from MIDI IN. Otherwise you will get duplicate tones.

# Installation

In Ubuntu e.g.

    sudo apt-get install ceylon-1.2.0
    ceylon compile
    ceylon run --flat-classpath my.midifilter

Then connect your midi cables to your keyboard and start playing :)

Try commenting/uncommenting the various entries in the "value filters" list near the end of [run.ceylon](https://github.com/xkr47/midi-filter.ceylon/blob/master/source/my/midifilter/run.ceylon).

Pull requests welcome :)
